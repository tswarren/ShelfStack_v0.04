# frozen_string_literal: true

module Pos
  class TransactionsController < BaseController
    before_action -> { authorize_pos!("pos.transactions.view") }, only: %i[index show]
    before_action -> { authorize_pos!("pos.transactions.create") }, only: %i[new create]
    before_action -> { authorize_pos!("pos.transactions.update") }, only: %i[edit update sync_tenders]
    before_action -> { authorize_pos!("pos.lines.add") }, only: %i[add_line]
    before_action -> { authorize_pos!("pos.lines.add.open_ring") }, only: %i[add_open_ring_line]
    before_action -> { authorize_pos!("pos.lines.update") }, only: %i[update_line]
    before_action -> { authorize_pos!("pos.lines.remove") }, only: %i[remove_line]
    before_action -> { authorize_pos!("pos.returns.receipted") }, only: %i[add_return_line]
    before_action -> { authorize_pos!("pos.transactions.complete") }, only: %i[complete]
    before_action -> { authorize_pos!("pos.transactions.suspend") }, only: %i[suspend]
    before_action -> { authorize_pos!("pos.transactions.resume") }, only: %i[resume]
    before_action -> { authorize_pos!("pos.transactions.void") }, only: %i[void]
    before_action -> { authorize_pos!("pos.transactions.cancel") }, only: %i[cancel]
    before_action :set_transaction, only: %i[
      show edit update add_line add_open_ring_line add_return_line update_line remove_line
      sync_tenders complete suspend resume void cancel
    ]
    before_action :ensure_editable, only: %i[
      edit update add_line add_open_ring_line add_return_line update_line remove_line sync_tenders
    ]

    def index
      @transactions = PosTransaction.where(store: pos_store).order(updated_at: :desc).limit(50)
    end

    def show
    end

    def new
      @transaction = PosTransaction.new(store: pos_store, workstation: current_workstation, cashier_user: current_user, status: "draft")
    end

    def create
      @transaction = PosTransaction.create!(
        store: pos_store,
        workstation: current_workstation,
        cashier_user: current_user,
        status: "draft"
      )
      record_audit!("pos.transaction.created", @transaction)
      redirect_to edit_pos_transaction_path(@transaction, mode: params[:mode].presence || "sale")
    end

    def edit
      @mode = pos_mode
      @inactive_warnings = Pos::SellabilityValidator.warnings_for(@transaction)
      @complete_error = flash[:complete_error]
      @sub_departments = SubDepartment.active_records.order(:name)
    end

    def update
      attrs = transaction_params
      attrs[:discount_cents] = parse_dollar_param(params.dig(:pos_transaction, :discount_dollars)) if params.dig(:pos_transaction, :discount_dollars).present?
      attrs[:rounding_cents] = parse_dollar_param(params.dig(:pos_transaction, :rounding_dollars)) if params.dig(:pos_transaction, :rounding_dollars).present?

      @transaction.update!(attrs)
      Pos::RecalculateTransaction.call!(@transaction)
      redirect_to edit_pos_transaction_path(@transaction, mode: pos_mode), notice: "Transaction updated."
    end

    def add_line
      variant = ProductVariant.find(params[:product_variant_id])
      quantity = params[:quantity].to_i
      quantity = 1 if quantity.zero?
      quantity = -quantity.abs if pos_mode == "return" && quantity.positive?

      if pos_mode == "return" && params[:source_transaction_line_id].blank?
        unless Authorization.allowed?(user: current_user, permission_key: "pos.returns.no_receipt", store: pos_store)
          redirect_to edit_pos_transaction_path(@transaction, mode: pos_mode), alert: "No-receipt returns require permission."
          return
        end
      end

      unit_price_cents = parse_dollar_param(params[:unit_price]) || variant.selling_price_cents

      @transaction.pos_transaction_lines.create!(
        line_number: next_line_number,
        line_type: "variant",
        product_variant: variant,
        product: variant.product,
        quantity: quantity,
        unit_price_cents: unit_price_cents,
        line_discount_cents: 0,
        extended_price_cents: 0,
        tax_cents: 0,
        return_disposition: (pos_mode == "return" ? "return_to_stock" : nil)
      )

      Pos::RecalculateTransaction.call!(@transaction.reload)
      redirect_to edit_pos_transaction_path(@transaction, mode: pos_mode), notice: "Line added."
    end

    def add_return_line
      source_line = PosTransactionLine
        .joins(:pos_transaction)
        .where(pos_transactions: { store: pos_store, status: "completed" })
        .find(params[:source_transaction_line_id])

      quantity = -params[:quantity].to_i.abs
      quantity = -1 if quantity.zero?

      line = @transaction.pos_transaction_lines.create!(
        line_number: next_line_number,
        line_type: "variant",
        product_variant: source_line.product_variant,
        product: source_line.product,
        quantity: quantity,
        unit_price_cents: 0,
        line_discount_cents: 0,
        extended_price_cents: 0,
        tax_cents: 0,
        source_transaction: source_line.pos_transaction,
        source_transaction_line: source_line,
        source_sold_quantity_snapshot: source_line.quantity.abs,
        return_disposition: params[:return_disposition].presence || "return_to_stock"
      )

      Pos::ReturnLinePricing.apply!(line)
      Pos::RecalculateTransaction.call!(@transaction.reload)
      redirect_to edit_pos_transaction_path(@transaction, mode: "return"), notice: "Return line added."
    rescue ActiveRecord::RecordNotFound
      redirect_to edit_pos_transaction_path(@transaction, mode: "return"), alert: "Source sale line not found."
    end

    def add_open_ring_line
      sub_department = SubDepartment.active_records.find(params[:sub_department_id])
      quantity = params[:quantity].to_i
      quantity = 1 if quantity.zero?
      unit_price_cents = parse_dollar_param(params[:unit_price]) || 0

      tax = Pos::TaxCalculator.snapshot_for_subdepartment!(
        sub_department: sub_department,
        store: pos_store,
        business_date: current_register_session&.business_date || Date.current,
        taxable_cents: unit_price_cents * quantity.abs
      )

      variant = params[:product_variant_id].presence && ProductVariant.find_by(id: params[:product_variant_id])

      @transaction.pos_transaction_lines.create!(
        line_number: next_line_number,
        line_type: "open_ring",
        product_variant: variant,
        product: variant&.product,
        quantity: quantity,
        unit_price_cents: unit_price_cents,
        line_discount_cents: 0,
        extended_price_cents: unit_price_cents * quantity.abs,
        tax_cents: tax.tax_cents,
        open_ring_description: params[:description].presence || "Open ring item",
        sub_department: sub_department,
        tax_category: tax.tax_category,
        tax_rate_bps: tax.tax_rate_bps,
        store_tax_rate: tax.store_tax_rate,
        tax_identifier_snapshot: tax.store_tax_rate&.tax_identifier,
        store_tax_rate_short_name_snapshot: tax.store_tax_rate&.short_name,
        inventory_behavior_snapshot: variant&.inventory_behavior
      )

      Pos::RecalculateTransaction.call!(@transaction.reload)
      redirect_to edit_pos_transaction_path(@transaction, mode: pos_mode), notice: "Open-ring line added."
    rescue Pos::TaxCalculator::MissingTaxError => e
      redirect_to edit_pos_transaction_path(@transaction, mode: pos_mode), alert: e.message
    end

    def update_line
      line = @transaction.pos_transaction_lines.find(params[:line_id])
      attrs = {}
      attrs[:quantity] = params[:quantity].to_i if params.key?(:quantity)
      attrs[:unit_price_cents] = parse_dollar_param(params[:unit_price]) if params[:unit_price].present?
      if params[:line_discount].present?
        authorize_pos!("pos.discounts.line.apply")
        attrs[:line_discount_cents] = parse_dollar_param(params[:line_discount])
      end
      attrs[:return_disposition] = params[:return_disposition] if params.key?(:return_disposition)
      line.update!(attrs)
      Pos::RecalculateTransaction.call!(@transaction.reload)
      redirect_to edit_pos_transaction_path(@transaction, mode: pos_mode), notice: "Line updated."
    end

    def remove_line
      line = @transaction.pos_transaction_lines.find(params[:line_id])
      line.destroy!
      Pos::RecalculateTransaction.call!(@transaction.reload)
      redirect_to edit_pos_transaction_path(@transaction, mode: pos_mode), notice: "Line removed."
    end

    def sync_tenders
      result = Pos::TenderSync.call!(transaction: @transaction, tender_inputs: params[:tenders])
      notice = ["Tenders updated.", result.message].compact.join(" ")
      redirect_to edit_pos_transaction_path(@transaction, mode: pos_mode), notice: notice
    rescue Pos::TenderSync::Error => e
      redirect_to edit_pos_transaction_path(@transaction, mode: pos_mode), alert: e.message
    end

    def complete
      register_session = current_register_session
      if register_session.blank?
        redirect_to edit_pos_transaction_path(@transaction, mode: pos_mode), alert: "Open a register session before completing."
        return
      end

      Pos::CompleteTransaction.call!(
        transaction: @transaction,
        completed_by_user: current_user,
        register_session: register_session,
        confirmed_inactive: params[:confirm_inactive].present?,
        pos_authorization_id: params[:pos_authorization_id]
      )
      redirect_to pos_transaction_path(@transaction), notice: "Transaction completed."
    rescue StandardError => e
      flash[:complete_error] = e.message
      redirect_to edit_pos_transaction_path(@transaction, mode: pos_mode, confirm_inactive: params[:confirm_inactive])
    end

    def suspend
      @transaction.update!(status: "suspended", suspended_at: Time.current)
      record_audit!("pos.transaction.suspended", @transaction)
      redirect_to pos_root_path, notice: "Transaction suspended."
    end

    def resume
      if @transaction.cashier_user_id != current_user.id
        authorize_pos!("pos.transactions.resume.other_cashier")
      end

      @transaction.update!(status: "draft", suspended_at: nil)
      record_audit!("pos.transaction.resumed", @transaction)
      redirect_to edit_pos_transaction_path(@transaction), notice: "Transaction resumed."
    end

    def void
      register_session = current_register_session
      Pos::VoidTransaction.call!(
        transaction: @transaction,
        voided_by_user: current_user,
        register_session: register_session,
        reason_code: params[:reason_code],
        notes: params[:notes]
      )
      redirect_to pos_transaction_path(@transaction), notice: "Transaction voided."
    rescue StandardError => e
      redirect_to pos_transaction_path(@transaction), alert: e.message
    end

    def cancel
      @transaction.update!(status: "cancelled")
      record_audit!("pos.transaction.cancelled", @transaction)
      redirect_to pos_root_path, notice: "Transaction cancelled."
    end

    private

    def set_transaction
      @transaction = PosTransaction.where(store: pos_store).find(params[:id])
    end

    def ensure_editable
      return if @transaction.editable?

      redirect_to pos_transaction_path(@transaction), alert: "Transaction is not editable."
    end

    def next_line_number
      @transaction.pos_transaction_lines.maximum(:line_number).to_i + 1
    end


    def transaction_params
      params.require(:pos_transaction).permit(
        :discount_cents,
        :rounding_cents,
        :notes,
        pos_tenders_attributes: %i[id tender_type amount_cents reference_number _destroy]
      )
    end
  end
end
