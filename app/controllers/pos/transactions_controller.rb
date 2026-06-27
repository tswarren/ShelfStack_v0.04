# frozen_string_literal: true

module Pos
  class TransactionsController < BaseController
    before_action -> { authorize_pos!("pos.transactions.view") }, only: %i[index show]
    before_action -> { authorize_pos!("pos.transactions.create") }, only: %i[new create]
    before_action -> { authorize_pos!("pos.transactions.update") }, only: %i[edit update sync_tenders readiness_preview]
    before_action -> { authorize_pos!("pos.lines.add") }, only: %i[add_line route_command]
    before_action -> { authorize_pos!("pos.lines.update") }, only: %i[update_line]
    before_action -> { authorize_pos!("pos.fulfill_customer_reservation") }, only: :add_reservation_line
    before_action -> { authorize_pos!("pos.gift_cards.issue") }, only: %i[add_gift_card_sale_line update_gift_card_sale_line]
    before_action -> { authorize_pos!("pos.discounts.line.apply") }, only: :apply_line_discount
    before_action -> { authorize_pos!("pos.discounts.transaction.apply") }, only: :apply_transaction_discount
    before_action -> { authorize_pos!("pos.discounts.void") }, only: :void_discount_application
    before_action -> { authorize_pos!("pos.tax_exemptions.apply") }, only: :apply_tax_exemption
    before_action -> { authorize_pos!("pos.tax_exemptions.void") }, only: :void_tax_exemption
    before_action -> { authorize_pos!("pos.tax_overrides.line.apply") }, only: :apply_line_tax_override
    before_action -> { authorize_pos!("pos.tax_overrides.line.void") }, only: :void_line_tax_override
    before_action -> { authorize_pos!("pos.lines.remove") }, only: %i[remove_line]
    before_action -> { authorize_pos!("pos.returns.receipted") }, only: %i[add_return_line]
    before_action -> { authorize_pos!("pos.transactions.complete") }, only: %i[complete]
    before_action -> { authorize_pos!("pos.transactions.suspend") }, only: %i[suspend]
    before_action -> { authorize_pos!("pos.transactions.resume") }, only: %i[resume]
    before_action -> { authorize_pos!("pos.transactions.void") }, only: %i[void]
    before_action -> { authorize_pos!("pos.transactions.cancel") }, only: %i[cancel]
    before_action :set_transaction, only: %i[
      show edit update add_line add_reservation_line add_open_ring_line add_gift_card_sale_line add_return_line
      update_line update_gift_card_sale_line remove_line apply_line_discount apply_transaction_discount void_discount_application
      apply_tax_exemption void_tax_exemption apply_line_tax_override void_line_tax_override
      sync_tenders complete suspend resume void cancel readiness_preview route_command
    ]
    before_action :ensure_editable, only: %i[
      edit update add_line add_reservation_line add_open_ring_line add_gift_card_sale_line add_return_line
      update_line update_gift_card_sale_line remove_line apply_line_discount apply_transaction_discount
      void_discount_application apply_tax_exemption void_tax_exemption apply_line_tax_override void_line_tax_override sync_tenders route_command
    ]
    before_action :load_edit_context, only: %i[
      edit add_line add_reservation_line add_open_ring_line add_gift_card_sale_line add_return_line
      update_line update_gift_card_sale_line remove_line sync_tenders route_command
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
      result = Pos::DraftCreator.call(
        store: pos_store,
        workstation: current_workstation,
        cashier_user: current_user,
        register_session: current_register_session,
        user_session: Current.user_session
      )

      case result.status
      when :missing_register_session
        redirect_to pos_root_path, alert: "Open the register before starting a sale."
      when :invalid_register_session
        redirect_to pos_root_path, alert: "Register session does not match the current workstation."
      when :conflict
        redirect_to pos_root_path, alert: "Multiple active drafts exist. Resolve the conflict before starting a new sale."
      when :legacy_found
        redirect_to pos_root_path, alert: "An older draft needs review before starting a new sale."
      when :created
        @transaction = result.transaction
        record_audit!("pos.transaction.created", @transaction)
        redirect_to edit_pos_transaction_path(@transaction, mode: params[:mode].presence || "sale")
      when :resumed
        redirect_to edit_pos_transaction_path(result.transaction, mode: params[:mode].presence || "sale")
      else
        redirect_to pos_root_path, alert: "Unable to start transaction."
      end
    end

    def edit
    end

    def update
      attrs = transaction_params
      if params.dig(:pos_transaction, :rounding_dollars).present?
        attrs[:rounding_cents] = parse_dollar_param(params.dig(:pos_transaction, :rounding_dollars))
      end

      @transaction.update!(attrs)
      Pos::RecalculateTransaction.call!(@transaction)
      redirect_to edit_pos_transaction_path(@transaction), notice: "Transaction updated."
    end

    def readiness_preview
      inputs = settlement_inputs
      readiness = build_readiness(tender_inputs: inputs)
      payload = Pos::ReadinessPreviewResponse.build(
        readiness: readiness,
        transaction: @transaction,
        confirm_inactive: params[:confirm_inactive].present?,
        tender_inputs: inputs
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
        transaction: @transaction,
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

    def add_gift_card_sale_line
      amount_cents = parse_dollar_param(params[:unit_price]) || params[:amount_cents].to_i
      Pos::AddGiftCardSaleLine.call!(
        transaction: @transaction,
        actor: current_user,
        amount_cents: amount_cents,
        line_number: next_line_number
      )
      respond_to_workspace(notice: "Gift card sale line added.")
    rescue Pos::AddGiftCardSaleLine::Error => e
      respond_to_workspace(alert: e.message, status: :unprocessable_entity)
    end

    def update_gift_card_sale_line
      line = @transaction.pos_transaction_lines.find(params[:line_id])
      Pos::UpdateGiftCardSaleLine.call!(
        line: line,
        actor: current_user,
        lookup_code: params[:lookup_code],
        clear_card_number: ActiveModel::Type::Boolean.new.cast(params[:clear_card_number]),
        generate_identifier: params[:generate_identifier],
        unit_price_cents: (parse_dollar_param(params[:unit_price]) if params[:unit_price].present?)
      )
      respond_to_workspace(notice: "Gift card line updated.")
    rescue Pos::UpdateGiftCardSaleLine::Error => e
      respond_to_workspace(alert: e.message, status: :unprocessable_entity)
    end

    def update_line
      line = @transaction.pos_transaction_lines.find(params[:line_id])
      attrs = {}

      if params[:quantity_delta].present?
        unless line.gift_card_sale_line?
          delta = params[:quantity_delta].to_i
          attrs[:quantity] = if line.quantity.negative?
            line.quantity - delta
          else
            line.quantity + delta
          end
        end
      elsif params.key?(:quantity)
        attrs[:quantity] = params[:quantity].to_i
      end

      attrs[:unit_price_cents] = parse_dollar_param(params[:unit_price]) if params[:unit_price].present? && line_price_editable?(line)
      attrs[:return_disposition] = params[:return_disposition] if params.key?(:return_disposition)

      if attrs.key?(:quantity) && attrs[:quantity].to_i.zero?
        line.destroy!
      elsif attrs.any?
        line.update!(attrs)
      end

      Pos::RecalculateTransaction.call!(@transaction.reload)
      respond_to_workspace(notice: "Line updated.")
    end

    def apply_line_discount
      line = @transaction.pos_transaction_lines.find(params[:line_id])
      reason = DiscountReason.active_records.find(params[:discount_reason_id])
      method, entered_amount_cents, entered_percent_bps = discount_entry_params(line)

      Pos::DiscountApplicationService.call!(
        transaction: @transaction,
        scope: "line",
        line: line,
        discount_reason: reason,
        discount_method: method,
        entered_amount_cents: entered_amount_cents,
        entered_percent_bps: entered_percent_bps,
        note: params[:discount_note],
        actor: current_user,
        pos_authorization: pos_discount_authorization
      )
      refresh_transaction_after_discount_change!
      respond_to_workspace(notice: "Line discount applied.")
    rescue Pos::DiscountApplicationService::Error, Pos::DiscountInput::Error, ActiveRecord::RecordNotFound => e
      flash.now[:alert] = e.message
      load_edit_context
      respond_to do |format|
        format.turbo_stream { render :update_workspace, status: :unprocessable_entity }
        format.html { redirect_to edit_pos_transaction_path(@transaction), alert: e.message }
      end
    end

    def apply_transaction_discount
      reason = DiscountReason.active_records.find(params[:discount_reason_id])
      method, entered_amount_cents, entered_percent_bps = discount_entry_params(@transaction)

      Pos::DiscountApplicationService.call!(
        transaction: @transaction,
        scope: "transaction",
        discount_reason: reason,
        discount_method: method,
        entered_amount_cents: entered_amount_cents,
        entered_percent_bps: entered_percent_bps,
        note: params[:discount_note],
        actor: current_user,
        pos_authorization: pos_discount_authorization
      )
      refresh_transaction_after_discount_change!
      respond_to_workspace(notice: "Transaction discount applied.")
    rescue Pos::DiscountApplicationService::Error, Pos::DiscountInput::Error, ActiveRecord::RecordNotFound => e
      flash.now[:alert] = e.message
      load_edit_context
      respond_to do |format|
        format.turbo_stream { render :update_workspace, status: :unprocessable_entity }
        format.html { redirect_to edit_pos_transaction_path(@transaction), alert: e.message }
      end
    end

    def void_discount_application
      application = @transaction.pos_discount_applications.find(params[:application_id])
      Pos::VoidDiscountApplication.call!(
        application: application,
        actor: current_user,
        void_reason: params[:void_reason]
      )
      refresh_transaction_after_discount_change!
      respond_to_workspace(notice: "Discount removed.")
    rescue Pos::VoidDiscountApplication::Error, ActiveRecord::RecordNotFound => e
      respond_to_workspace(alert: e.message, status: :unprocessable_entity)
    end

    def apply_tax_exemption
      reason = TaxExceptionReason.active_records.for_exemption.find(params[:tax_exception_reason_id])

      Pos::TaxExceptionApplicationService.call!(
        transaction: @transaction,
        scope: "transaction",
        tax_exception_reason: reason,
        certificate_number: params[:certificate_number],
        note: params[:tax_exemption_note],
        actor: current_user
      )
      refresh_transaction_after_discount_change!
      respond_to_workspace(notice: "Tax exemption applied.")
    rescue Pos::TaxExceptionApplicationService::Error, ActiveRecord::RecordNotFound => e
      flash.now[:alert] = e.message
      load_edit_context
      respond_to do |format|
        format.turbo_stream { render :update_workspace, status: :unprocessable_entity }
        format.html { redirect_to edit_pos_transaction_path(@transaction), alert: e.message }
      end
    end

    def void_tax_exemption
      exemption = @transaction.pos_tax_exemptions.find(params[:exemption_id])
      Pos::VoidTaxException.call!(
        record: exemption,
        actor: current_user,
        void_reason: params[:void_reason]
      )
      refresh_transaction_after_discount_change!
      respond_to_workspace(notice: "Tax exemption removed.")
    rescue Pos::VoidTaxException::Error, ActiveRecord::RecordNotFound => e
      respond_to_workspace(alert: e.message, status: :unprocessable_entity)
    end

    def apply_line_tax_override
      line = @transaction.pos_transaction_lines.find(params[:line_id])
      reason = TaxExceptionReason.active_records.for_rate_override.find(params[:tax_exception_reason_id])
      category = TaxCategory.active_records.find(params[:override_tax_category_id])

      Pos::TaxExceptionApplicationService.call!(
        transaction: @transaction,
        scope: "line",
        line: line,
        tax_exception_reason: reason,
        override_tax_category: category,
        note: params[:tax_override_note],
        actor: current_user
      )
      refresh_transaction_after_discount_change!
      respond_to_workspace(notice: "Line tax override applied.")
    rescue Pos::TaxExceptionApplicationService::Error, ActiveRecord::RecordNotFound => e
      flash.now[:alert] = e.message
      load_edit_context
      respond_to do |format|
        format.turbo_stream { render :update_workspace, status: :unprocessable_entity }
        format.html { redirect_to edit_pos_transaction_path(@transaction), alert: e.message }
      end
    end

    def void_line_tax_override
      override = @transaction.pos_line_tax_overrides.find(params[:override_id])
      Pos::VoidTaxException.call!(
        record: override,
        actor: current_user,
        void_reason: params[:void_reason]
      )
      refresh_transaction_after_discount_change!
      respond_to_workspace(notice: "Line tax override removed.")
    rescue Pos::VoidTaxException::Error, ActiveRecord::RecordNotFound => e
      respond_to_workspace(alert: e.message, status: :unprocessable_entity)
    end

    def remove_line
      line = @transaction.pos_transaction_lines.find(params[:line_id])
      line.destroy!
      Pos::RecalculateTransaction.call!(@transaction.reload)
      respond_to_workspace(notice: "Line removed.")
    end

    def sync_tenders
      result = Pos::SettlementSync.call!(
        transaction: @transaction,
        tender_inputs: settlement_inputs,
        actor: current_user
      )
      @transaction.reload
      store_pos_generated_identifier_flash!(result.generated_identifiers)
      notice = [ "Settlement updated.", result.message ].compact.join(" ")
      respond_to_workspace(notice: notice)
    rescue Pos::SettlementSync::Error => e
      respond_to_workspace(alert: e.message, status: :unprocessable_entity)
    end

    def complete
      register_session = current_register_session
      if register_session.blank?
        redirect_to edit_pos_transaction_path(@transaction), alert: "Open a register session before completing."
        return
      end

      generated_identifiers = []
      if settlement_inputs.present?
        sync_result = Pos::SettlementSync.call!(
          transaction: @transaction,
          tender_inputs: settlement_inputs,
          actor: current_user
        )
        generated_identifiers.concat(sync_result.generated_identifiers)
        @transaction.reload
      end

      completed_transaction = Pos::CompleteTransaction.call!(
        transaction: @transaction,
        completed_by_user: current_user,
        register_session: register_session,
        confirmed_inactive: params[:confirm_inactive].present?,
        pos_authorization_id: params[:pos_authorization_id]
      )
      generated_identifiers.concat(completed_transaction.pos_generated_stored_value_identifiers || [])
      store_pos_generated_identifier_flash!(generated_identifiers)
      redirect_to pos_transaction_path(completed_transaction), notice: completion_notice(generated_identifiers)
    rescue Pos::SettlementSync::Error => e
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
        pos_authorization_id: params[:pos_authorization_id],
        actor: current_user
      )
    end

    def settlement_inputs
      inputs = params[:settlements] || params[:tenders]
      return inputs if inputs.blank?
      return inputs unless inputs.respond_to?(:to_unsafe_h)

      hash = inputs.to_unsafe_h
      return inputs unless hash.keys.all? { |key| key.to_s.match?(/\A\d+\z/) }

      hash.sort_by { |key, _| key.to_i }.map { |_, value| value }
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

    def discount_entry_params(target)
      base_cents = discount_entry_base_cents(target)
      input_type = params[:discount_type].presence || "amount"
      method = input_type == "percent" ? "percent" : "amount"

      if method == "percent"
        percent = BigDecimal(params[:discount_value].to_s)
        raise Pos::DiscountInput::Error, "Percent must be between 0 and 100." if percent.negative? || percent > 100

        entered_percent_bps = (percent * 100).to_i
        entered_amount_cents = nil
      else
        entered_amount_cents = Pos::DiscountInput.resolve_cents(
          value: params[:discount_value],
          input_type: "amount",
          base_cents: base_cents
        )
        entered_percent_bps = nil
      end

      [ method, entered_amount_cents, entered_percent_bps ]
    end

    def discount_entry_base_cents(target)
      if target.is_a?(PosTransaction)
        Pos::DiscountInput.discountable_transaction_base_cents(target.reload)
      else
        [ Pos::DiscountInput.line_base_cents(target) - target.line_discount_cents.to_i - target.transaction_discount_cents.to_i, 0 ].max
      end
    end

    def refresh_transaction_after_discount_change!
      @transaction = Pos::RecalculateTransaction.call!(
        @transaction.reload,
        business_date: current_register_session&.business_date || @transaction.business_date || Date.current
      )
      @transaction.reload
    end

    def pos_discount_authorization
      return @pos_discount_authorization if defined?(@pos_discount_authorization)

      @pos_discount_authorization = if params[:pos_authorization_id].present?
        PosAuthorization.find_by(id: params[:pos_authorization_id])
      end
    end

    def transaction_params
      params.require(:pos_transaction).permit(
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

    def store_pos_generated_identifier_flash!(generated_identifiers)
      return if generated_identifiers.blank?

      flash[:pos_generated_stored_value_identifiers] = generated_identifiers.map do |generated|
        {
          "display_value" => generated.display_value,
          "pos_tender_id" => generated.pos_tender_id,
          "pos_transaction_line_id" => generated.pos_transaction_line_id
        }
      end
    end

    def completion_notice(generated_identifiers)
      notice = "Transaction completed."
      return notice if generated_identifiers.blank?

      values = generated_identifiers.map(&:display_value).join(", ")
      "#{notice} New store credit identifier: #{values}."
    end
  end
end
