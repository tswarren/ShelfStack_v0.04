# frozen_string_literal: true

module Pos
  class TransactionsController < BaseController
    before_action -> { authorize_pos!("pos.transactions.view") }, only: %i[index show]
    before_action -> { authorize_pos!("pos.transactions.create") }, only: %i[new create]
    before_action -> { authorize_pos!("pos.transactions.update") }, only: %i[edit update sync_tenders readiness_preview]
    before_action -> { authorize_pos!("pos.lines.add") }, only: %i[add_line route_command]
    before_action -> { authorize_pos!("pos.fulfill_customer_reservation") }, only: :add_reservation_line
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
      show edit update add_line add_reservation_line add_open_ring_line add_return_line update_line remove_line
      sync_tenders complete suspend resume void cancel readiness_preview route_command
    ]
    before_action :ensure_editable, only: %i[
      edit update add_line add_reservation_line add_open_ring_line add_return_line update_line remove_line sync_tenders route_command
    ]
    before_action :load_edit_context, only: %i[edit add_line add_reservation_line add_open_ring_line add_return_line update_line remove_line sync_tenders route_command]

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
    end

    def update
      attrs = transaction_params
      if params.dig(:pos_transaction, :rounding_dollars).present?
        attrs[:rounding_cents] = parse_dollar_param(params.dig(:pos_transaction, :rounding_dollars))
      end
      apply_transaction_discount_attrs!(attrs)

      @transaction.update!(attrs)
      Pos::RecalculateTransaction.call!(@transaction)
      redirect_to edit_pos_transaction_path(@transaction), notice: "Transaction updated."
    rescue Pos::DiscountInput::Error => e
      redirect_to edit_pos_transaction_path(@transaction), alert: e.message
    end

    def readiness_preview
      readiness = build_readiness(tender_inputs: params[:tenders])
      payload = Pos::ReadinessPreviewResponse.build(
        readiness: readiness,
        transaction: @transaction,
        confirm_inactive: params[:confirm_inactive].present?,
        tender_inputs: params[:tenders]
      )
      payload[:panel_html] = render_to_string(
        partial: "pos/transactions/readiness_panel",
        formats: [ :html ],
        locals: { transaction: @transaction, readiness: readiness }
      )

      render json: payload
    end

    def route_command
      route = Pos::CommandBarRouter.call(
        store: pos_store,
        input: params[:input],
        return_mode: ActiveModel::Type::Boolean.new.cast(params[:return_mode])
      )

      render json: {
        action: route.action,
        payload: serialize_route_payload(route.payload),
        message: route.message
      }
    end

    def add_line
      entry_action = line_entry_action
      variant = ProductVariant.find(params[:product_variant_id])
      quantity = params[:quantity].to_i
      quantity = 1 if quantity.zero?
      quantity = -quantity.abs if negative_line_entry?(entry_action) && quantity.positive?

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
        return_disposition: (negative_line_entry?(entry_action) ? "return_to_stock" : nil)
      )

      Pos::RecalculateTransaction.call!(@transaction.reload)
      respond_to_workspace(notice: "Line added.")
    end

    def add_reservation_line
      reservation = InventoryReservation.find(params[:inventory_reservation_id])
      quantity = params[:quantity].presence&.to_i
      quantity = 1 if quantity.nil? || quantity <= 0

      Pos::AddReservationLine.call!(
        transaction: @transaction,
        reservation: reservation,
        added_by_user: current_user,
        quantity: quantity
      )
      respond_to_workspace(notice: "Pickup line added.")
    rescue Pos::AddReservationLine::Error => e
      respond_to_workspace(alert: e.message)
    end

    def add_return_line
      source_line = PosTransactionLine
        .joins(:pos_transaction)
        .where(pos_transactions: { store: pos_store, status: "completed" })
        .find(params[:source_transaction_line_id])

      quantity = -params[:quantity].to_i.abs
      quantity = -1 if quantity.zero?

      line_attrs = {
        line_number: next_line_number,
        quantity: quantity,
        unit_price_cents: 0,
        line_discount_cents: 0,
        extended_price_cents: 0,
        tax_cents: 0,
        source_transaction: source_line.pos_transaction,
        source_transaction_line: source_line,
        source_sold_quantity_snapshot: source_line.quantity.abs,
        return_disposition: params[:return_disposition].presence || "return_to_stock"
      }

      if source_line.open_ring_line?
        line_attrs.merge!(
          line_type: "open_ring",
          open_ring_description: source_line.open_ring_description,
          sub_department: source_line.sub_department,
          sub_department_name_snapshot: source_line.sub_department_name_snapshot.presence || source_line.sub_department&.name,
          tax_category: source_line.tax_category,
          tax_rate_bps: source_line.tax_rate_bps,
          store_tax_rate: source_line.store_tax_rate,
          tax_identifier_snapshot: source_line.tax_identifier_snapshot,
          store_tax_rate_short_name_snapshot: source_line.store_tax_rate_short_name_snapshot,
          inventory_behavior_snapshot: source_line.inventory_behavior_snapshot
        )
      else
        line_attrs.merge!(
          line_type: "variant",
          product_variant: source_line.product_variant,
          product: source_line.product
        )
      end

      line = @transaction.pos_transaction_lines.create!(line_attrs)

      Pos::ReturnLinePricing.apply!(line)
      Pos::RecalculateTransaction.call!(@transaction.reload)
      respond_to_workspace(notice: "Return line added.")
    rescue ActiveRecord::RecordNotFound
      respond_to_workspace(alert: "Source sale line not found.", status: :unprocessable_entity)
    end

    def add_open_ring_line
      sub_department = SubDepartment.active_records.find(params[:sub_department_id])
      quantity = params[:quantity].to_i
      quantity = 1 if quantity.zero?
      quantity = -quantity.abs if negative_line_entry?(params[:entry_action])
      unit_price_cents = parse_dollar_param(params[:unit_price]) || 0

      tax = Pos::TaxCalculator.snapshot_for_subdepartment!(
        sub_department: sub_department,
        store: pos_store,
        business_date: current_register_session&.business_date || Date.current,
        taxable_cents: unit_price_cents * quantity.abs
      )

      variant = params[:product_variant_id].presence && ProductVariant.find_by(id: params[:product_variant_id])
      return_line = quantity.negative?

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
        sub_department_name_snapshot: sub_department.name,
        tax_category: tax.tax_category,
        tax_rate_bps: tax.tax_rate_bps,
        store_tax_rate: tax.store_tax_rate,
        tax_identifier_snapshot: tax.store_tax_rate&.tax_identifier,
        store_tax_rate_short_name_snapshot: tax.store_tax_rate&.short_name,
        inventory_behavior_snapshot: variant&.inventory_behavior,
        return_disposition: (return_line ? "return_to_stock" : nil)
      )

      Pos::RecalculateTransaction.call!(@transaction.reload)
      respond_to_workspace(notice: return_line ? "Open-ring return line added." : "Open-ring line added.")
    rescue Pos::TaxCalculator::MissingTaxError => e
      respond_to_workspace(alert: e.message, status: :unprocessable_entity)
    end

    def update_line
      line = @transaction.pos_transaction_lines.find(params[:line_id])
      attrs = {}

      if params[:quantity_delta].present?
        delta = params[:quantity_delta].to_i
        attrs[:quantity] = if line.quantity.negative?
          line.quantity - delta
        else
          line.quantity + delta
        end
      elsif params.key?(:quantity)
        attrs[:quantity] = params[:quantity].to_i
      end

      attrs[:unit_price_cents] = parse_dollar_param(params[:unit_price]) if params[:unit_price].present? && line_price_editable?(line)
      apply_line_discount_attrs!(line, attrs)
      attrs[:return_disposition] = params[:return_disposition] if params.key?(:return_disposition)

      if attrs.key?(:quantity) && attrs[:quantity].to_i.zero?
        line.destroy!
      elsif attrs.any?
        line.update!(attrs)
      end

      Pos::RecalculateTransaction.call!(@transaction.reload)
      respond_to_workspace(notice: "Line updated.")
    rescue Pos::DiscountInput::Error => e
      respond_to_workspace(alert: e.message, status: :unprocessable_entity)
    end

    def remove_line
      line = @transaction.pos_transaction_lines.find(params[:line_id])
      line.destroy!
      Pos::RecalculateTransaction.call!(@transaction.reload)
      respond_to_workspace(notice: "Line removed.")
    end

    def sync_tenders
      result = Pos::TenderSync.call!(transaction: @transaction, tender_inputs: params[:tenders])
      notice = [ "Tenders updated.", result.message ].compact.join(" ")
      respond_to_workspace(notice: notice)
    rescue Pos::TenderSync::Error => e
      respond_to_workspace(alert: e.message, status: :unprocessable_entity)
    end

    def complete
      register_session = current_register_session
      if register_session.blank?
        redirect_to edit_pos_transaction_path(@transaction), alert: "Open a register session before completing."
        return
      end

      if params[:tenders].present?
        Pos::TenderSync.call!(transaction: @transaction, tender_inputs: params[:tenders])
      end

      Pos::CompleteTransaction.call!(
        transaction: @transaction,
        completed_by_user: current_user,
        register_session: register_session,
        confirmed_inactive: params[:confirm_inactive].present?,
        pos_authorization_id: params[:pos_authorization_id]
      )
      redirect_to pos_transaction_path(@transaction), notice: "Transaction completed."
    rescue Pos::TenderSync::Error => e
      flash[:complete_error] = e.message
      redirect_to edit_pos_transaction_path(@transaction, confirm_inactive: params[:confirm_inactive])
    rescue StandardError => e
      flash[:complete_error] = e.message
      redirect_to edit_pos_transaction_path(@transaction, confirm_inactive: params[:confirm_inactive])
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
      if params[:reason_code].blank?
        redirect_to pos_transaction_path(@transaction), alert: "Void reason is required."
        return
      end

      unless void_authorization_valid?
        redirect_to pos_transaction_path(@transaction), alert: "Supervisor authorization required to void."
        return
      end

      register_session = current_register_session
      Pos::VoidTransaction.call!(
        transaction: @transaction,
        voided_by_user: current_user,
        register_session: register_session,
        reason_code: params[:reason_code],
        notes: params[:notes],
        pos_authorization: void_authorization
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
      @transaction = PosTransaction
        .includes(:cashier_user, :pos_receipt, :pos_tenders, pos_transaction_lines: :product_variant)
        .where(store: pos_store)
        .find(params[:id])
    end

    def ensure_editable
      return if @transaction.editable?

      redirect_to pos_transaction_path(@transaction), alert: "Transaction is not editable."
    end

    def load_edit_context
      @mode = pos_mode
      @entry_action = helpers.pos_initial_entry_action(@mode)
      @inactive_warnings = Pos::SellabilityValidator.warnings_for(@transaction)
      @complete_error = flash[:complete_error]
      @sub_departments = SubDepartment.active_records.order(:name)
      @readiness = build_readiness
    end

    def build_readiness(tender_inputs: nil)
      Pos::CompletionReadiness.check(
        transaction: @transaction.reload,
        register_session: current_register_session,
        tender_inputs: tender_inputs,
        confirmed_inactive: params[:confirm_inactive].present?,
        pos_authorization_id: params[:pos_authorization_id]
      )
    end

    def respond_to_workspace(notice: nil, alert: nil, status: :ok)
      load_edit_context
      flash.now[:notice] = notice if notice.present?
      flash.now[:alert] = alert if alert.present?

      respond_to do |format|
        format.turbo_stream { render :update_workspace, status: status }
        format.html do
          if alert.present?
            redirect_to edit_pos_transaction_path(@transaction), alert: alert
          else
            redirect_to edit_pos_transaction_path(@transaction), notice: notice
          end
        end
      end
    end

    def serialize_route_payload(payload)
      return payload unless payload[:variants]

      lookup_result = Pos::LineLookup::Result.new(
        status: payload[:status] || :found,
        variants: payload[:variants],
        message: nil
      )
      presented = Pos::LineLookupPresenter.as_json(lookup_result, store: pos_store)
      payload.merge(
        status: lookup_result.status.to_s,
        variants: presented[:variants]
      )
    end

    def next_line_number
      @transaction.pos_transaction_lines.maximum(:line_number).to_i + 1
    end

    def line_entry_action
      action = params[:entry_action].presence
      return action if PosHelper::ENTRY_ACTIONS.include?(action)

      if ActiveModel::Type::Boolean.new.cast(params[:return_mode])
        "return_no_receipt"
      else
        pos_mode == "return" ? "return_no_receipt" : "sale"
      end
    end

    def negative_line_entry?(entry_action)
      entry_action == "return_no_receipt" || ActiveModel::Type::Boolean.new.cast(params[:return_mode])
    end

    def line_price_editable?(line)
      !(line.return_line? && line.source_transaction_line_id.present?)
    end

    def apply_transaction_discount_attrs!(attrs)
      return unless params.dig(:pos_transaction)&.key?(:discount_value)

      attrs[:discount_cents] = Pos::DiscountInput.resolve_cents(
        value: params.dig(:pos_transaction, :discount_value),
        input_type: params.dig(:pos_transaction, :discount_type),
        base_cents: Pos::DiscountInput.discountable_transaction_base_cents(@transaction)
      )
    end

    def apply_line_discount_attrs!(line, attrs)
      return unless params.key?(:line_discount_value)

      authorize_pos!("pos.discounts.line.apply")
      attrs[:line_discount_cents] = Pos::DiscountInput.resolve_cents(
        value: params[:line_discount_value],
        input_type: params[:line_discount_type],
        base_cents: Pos::DiscountInput.line_base_cents(line)
      )
    end

    def transaction_params
      params.require(:pos_transaction).permit(
        :discount_cents,
        :rounding_cents,
        :notes,
        pos_tenders_attributes: %i[id tender_type amount_cents reference_number _destroy]
      )
    end

    def void_authorization
      return @void_authorization if defined?(@void_authorization)

      @void_authorization = if params[:pos_authorization_id].present?
        PosAuthorization.find_by(id: params[:pos_authorization_id])
      end
    end

    def void_authorization_valid?
      Pos::AuthorizationRequest.granted_for_transaction?(
        transaction: @transaction,
        authorization_type: "void_transaction",
        pos_authorization_id: void_authorization&.id
      )
    end
  end
end
