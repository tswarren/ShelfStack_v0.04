# frozen_string_literal: true

module Pos
  module GiftCardSaleSupport
    SUB_DEPARTMENT_KEY = "gift_cards"
    MAX_AMOUNT_CENTS = 10_000_00

    module_function

    def gift_card_sale_line?(line)
      line.is_a?(PosTransactionLine) && line.gift_card_sale_line?
    end

    def default_sub_department!
      SubDepartment.active_records.find_by!(sub_department_key: SUB_DEPARTMENT_KEY)
    end

    def activation_amount_cents(line)
      line.extended_price_cents.to_i
    end

    def activation_ready?(line)
      return false unless gift_card_sale_line?(line)

      line.stored_value_account_id.present? ||
        line.stored_value_identifier_id.present? ||
        line.generate_stored_value_identifier?
    end

    def reload_path?(line:, lookup_code: nil)
      lookup_code.present? || line.stored_value_account_id.present? || line.stored_value_identifier_id.present?
    end

    def validate_amount!(amount_cents)
      amount = amount_cents.to_i
      raise ArgumentError, "Gift card amount must be positive." if amount <= 0
      raise ArgumentError, "Gift card amount exceeds the allowed maximum." if amount > MAX_AMOUNT_CENTS

      amount
    end
  end
end
