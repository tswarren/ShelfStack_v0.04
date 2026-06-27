# frozen_string_literal: true

module Pos
  module CommandCarryForward
    module_function

    def edit_path(transaction:, carry_forward:, amount_cents: nil, receipt_number: nil, mode: "sale")
      params = { mode: mode, carry_forward: carry_forward }
      params[:amount_cents] = amount_cents if amount_cents.present?
      params[:receipt_number] = receipt_number if receipt_number.present?

      Rails.application.routes.url_helpers.edit_pos_transaction_path(transaction, **params)
    end

    def carry_forward_for(route_action)
      case route_action
      when :open_ring_offer
        "open_ring"
      when :gift_card_sale_offer
        "gift_card"
      when :return_drawer_offer
        "return"
      when :pickup_drawer_offer
        "pickup"
      else
        raise ArgumentError, "Unsupported carry-forward action: #{route_action.inspect}"
      end
    end

    def mode_for(route_action)
      route_action == :pickup_drawer_offer ? "pickup" : "sale"
    end
  end
end
