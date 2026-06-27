# frozen_string_literal: true

module Items
  class CustomerDemandActionsController < BaseController
    include Interaction::ToastStreamable

    before_action -> { authorize_demand!("customer_requests.create") }
    before_action -> { authorize_demand!("inventory_reservations.create") }, if: -> { hold_action? }
    before_action -> { authorize_demand!("special_orders.create") }, if: -> { special_order_action? }

    def create
      variant = ProductVariant.find(params[:product_variant_id])
      customer = resolve_customer

      override_user = if params[:override_reason].present? &&
                         Authorization.allowed?(user: current_user, permission_key: "inventory_reservations.override", store: current_store)
                        current_user
      end

      result = CustomerRequests::StartFromItem.call!(
        store: current_store,
        variant: variant,
        actor: current_user,
        request_type: params[:request_type],
        quantity: params[:quantity].presence&.to_i || 1,
        customer: customer,
        customer_name_snapshot: params[:customer_name_snapshot],
        customer_email_snapshot: params[:customer_email_snapshot],
        customer_phone_snapshot: params[:customer_phone_snapshot],
        preferred_contact_method: params[:preferred_contact_method],
        needed_by_date: params[:needed_by_date],
        notes: params[:notes],
        expires_at: parse_expires_at,
        override_authorized_by_user: override_user,
        override_reason: params[:override_reason]
      )

      notice = case params[:request_type]
      when "hold" then "Hold created for customer."
      when "special_order" then "Special order created."
      when "notify" then "Notify request created."
      else "Customer request created."
      end

      respond_to do |format|
        format.html do
          redirect_to customers_customer_request_path(result.request, anchor: "line-#{result.line.id}"),
                      notice: notice
        end
        format.turbo_stream do
          render turbo_stream: demand_create_success_streams(variant:, notice:)
        end
      end
    rescue CustomerRequests::StartFromItem::StartError,
           InventoryReservations::ReserveOnHand::ReserveError,
           SpecialOrders::CreateFromRequestLine::CreateError,
           SpecialOrders::Approve::ApproveError => e
      respond_to do |format|
        format.html do
          redirect_back fallback_location: items_item_path(tab: "operations", variant_id: params[:product_variant_id]),
                        alert: e.message
        end
        format.turbo_stream do
          render turbo_stream: append_toast_stream(message: e.message, variant: :error),
                 status: :unprocessable_entity
        end
      end
    end

    private

    def authorize_demand!(permission_key)
      return if Authorization.allowed?(user: current_user, permission_key: permission_key, store: current_store)

      redirect_back fallback_location: items_root_path, alert: "You are not authorized to perform that action."
    end

    def hold_action?
      params[:request_type].to_s == "hold"
    end

    def special_order_action?
      params[:request_type].to_s == "special_order"
    end

    def resolve_customer
      return nil if params[:customer_id].blank?

      Customer.find(params[:customer_id])
    end

    def parse_expires_at
      return nil if params[:expires_at].blank?

      Time.zone.parse(params[:expires_at])
    end

    def demand_create_success_streams(variant:, notice:)
      item = ItemPresenter.from_product_variant(variant)
      drawer = VariantOperationsDrawerPresenter.for(
        item: item,
        store: current_store,
        user: current_user,
        variant: variant
      )

      [
        turbo_stream.replace(
          "variant-ops-drawer-frame",
          partial: "items/items/variant_operations_drawer_body",
          locals: { drawer: drawer }
        ),
        append_toast_stream(message: notice, variant: :success)
      ]
    end
  end
end
