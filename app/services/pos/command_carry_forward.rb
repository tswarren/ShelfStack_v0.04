# frozen_string_literal: true

module Pos
  module CommandCarryForward
    module_function

    def edit_path(transaction:, carry_forward:, amount_cents: nil, mode: "sale")
      params = { mode: mode, carry_forward: carry_forward }
      params[:amount_cents] = amount_cents if amount_cents.present?

      Rails.application.routes.url_helpers.edit_pos_transaction_path(transaction, **params)
    end

    def carry_forward_for(route_action)
      case route_action
      when :open_ring_offer
        "open_ring"
      when :gift_card_sale_offer
        "gift_card"
      else
        raise ArgumentError, "Unsupported carry-forward action: #{route_action.inspect}"
      end
    end
  end
end
