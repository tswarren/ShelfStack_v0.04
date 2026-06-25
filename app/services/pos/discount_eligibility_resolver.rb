# frozen_string_literal: true

module Pos
  class DiscountEligibilityResolver
    Result = Data.define(:discountable, :reason_code, :message, :source)

    def self.call(line, remaining_discountable_cents: nil)
      new(line, remaining_discountable_cents:).call
    end

    def initialize(line, remaining_discountable_cents: nil)
      @line = line
      @remaining_discountable_cents = remaining_discountable_cents
    end

    def call
      system_result = system_ineligibility
      return system_result if system_result

      catalog_result = catalog_ineligibility
      return catalog_result if catalog_result

      Result.new(discountable: true, reason_code: nil, message: nil, source: nil)
    end

    private

    attr_reader :line, :remaining_discountable_cents

    def system_ineligibility
      if line.pos_transaction.present? && !line.pos_transaction.editable?
        return ineligible("transaction_locked", "Transaction is locked.", "system")
      end

      if line.return_line?
        return ineligible("return_line", "Return lines cannot be discounted.", "system")
      end

      if line.gift_card_sale_line?
        return ineligible("gift_card_sale", "Gift card sale lines cannot be discounted.", "system")
      end

      if line.quantity.to_i <= 0
        return ineligible("non_positive_quantity", "Only sale lines can be discounted.", "system")
      end

      if remaining_discountable_cents&.zero?
        return ineligible("zero_remaining_amount", "Nothing left to discount on this line.", "system")
      end

      nil
    end

    def catalog_ineligibility
      if line.product_variant.present? && !line.product_variant.discountable?
        return ineligible("variant_non_discountable", "This variant is not discountable.", "product_variant")
      end

      product = line.product || line.product_variant&.product
      if product.present? && !product.discountable?
        return ineligible("product_non_discountable", "This product is not discountable.", "product")
      end

      sub_department = line.sub_department || line.product_variant&.sub_department
      if sub_department.present? && !sub_department.discountable?
        return ineligible("sub_department_non_discountable", "This subdepartment is not discountable.", "sub_department")
      end

      department = sub_department&.department
      if department.present? && !department.discountable?
        return ineligible("department_non_discountable", "This department is not discountable.", "department")
      end

      nil
    end

    def ineligible(reason_code, message, source)
      Result.new(discountable: false, reason_code: reason_code, message: message, source: source)
    end
  end
end
