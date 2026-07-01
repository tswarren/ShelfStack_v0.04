# frozen_string_literal: true

module Items
  class DemandActionsController < BaseController
    include Interaction::ToastStreamable

    before_action -> { authorize_demand!("demand.create") }

    def create
      variant = ProductVariant.find(params[:product_variant_id])
      customer = resolve_customer
      capture_intent = params[:capture_intent].to_s

      demand_line = DemandLines::StartFromItem.call!(
        store: current_store,
        variant: variant,
        actor: current_user,
        capture_intent: capture_intent,
        quantity: params[:quantity].presence&.to_i || 1,
        customer: customer,
        customer_name_snapshot: params[:customer_name_snapshot],
        customer_email_snapshot: params[:customer_email_snapshot],
        customer_phone_snapshot: params[:customer_phone_snapshot],
        preferred_contact_method: params[:preferred_contact_method],
        needed_by_date: params[:needed_by_date],
        notes: params[:notes],
        expires_at: parse_expires_at
      )

      notice = demand_notice_for(capture_intent)

      respond_to do |format|
        format.html do
          redirect_to demand_demand_line_path(demand_line), notice: notice
        end
        format.turbo_stream do
          render turbo_stream: demand_create_success_streams(variant:, notice:)
        end
      end
    rescue DemandLines::StartFromItem::StartError,
           DemandLines::Create::CreateError => e
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

    def resolve_customer
      return nil if params[:customer_id].blank?

      Customer.find(params[:customer_id])
    end

    def parse_expires_at
      return nil if params[:expires_at].blank?

      Time.zone.parse(params[:expires_at].to_s)
    end

    def demand_notice_for(capture_intent)
      {
        "hold" => "Hold request recorded.",
        "special_order" => "Special order demand recorded.",
        "notify" => "Notify request recorded.",
        "used_wanted" => "Used wanted demand recorded.",
        "manual_tbo" => "Manual TBO demand recorded.",
        "buyer_replenishment" => "Buyer replenishment demand recorded."
      }[capture_intent] || "Demand line created."
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
        append_toast_stream(message: notice, variant: :success),
        turbo_stream.append(
          "demand_form_reset_triggers",
          partial: "shared/interaction/demand_form_reset_trigger"
        )
      ]
    end
  end
end
