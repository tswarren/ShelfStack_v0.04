# frozen_string_literal: true

module ProductVariants
  class OperationalPolicy
    Badge = Data.define(:key, :label)

    BLOCKING_PRODUCT_TYPES = %w[service financial].freeze

    PURCHASING_BLOCK_MESSAGES = {
      used_like: "Used variants cannot be added to normal vendor purchase orders.",
      inactive_product: "Product is inactive.",
      inactive_variant: "Variant is inactive.",
      gift_card_or_non_merchandise: "This item type cannot be added to a vendor purchase order.",
      not_orderable: "This variant is not orderable from vendors.",
      non_inventory_not_orderable: "Non-inventory variants require explicit orderable flag."
    }.freeze

    CUSTOMER_REQUEST_BLOCK_MESSAGES = {
      special_order: "Special orders are not available for used-like variants. Used stock is satisfied from on-hand inventory or future intake."
    }.freeze

    USED_NOT_VENDOR_ORDERABLE_INFO =
      "Used variant — not vendor-orderable. Available only from current stock or future intake."

    VENDOR_SOURCING_NOT_APPLICABLE =
      "Vendor sourcing is not applicable to used-like variants. Used stock is acquired through buyback/intake, not normal vendor ordering."

    def self.for(variant)
      new(variant)
    end

    def initialize(variant)
      @variant = variant
    end

    def new_condition?
      condition&.new_condition? == true
    end

    def used_condition?
      condition.present? && !new_condition?
    end

    # v0.04-5 default: non-new conditions are used-like for vendor-ordering rules.
    def used_like?
      used_condition?
    end

    def vendor_orderable?
      return false if variant.blank?
      return false unless variant.active?
      return false if product.blank? || !product.active?
      return false if BLOCKING_PRODUCT_TYPES.include?(product.product_type)
      return false if used_like?
      return false unless variant.orderable?
      return false if non_inventory_blocked?

      true
    end

    def customer_reservable?
      return false if variant.blank? || !variant.active?
      return false if product.blank? || !product.active?

      true
    end

    def buyback_eligible?(sub_department: nil)
      return false if condition.blank?

      sub = sub_department || variant&.sub_department
      condition.buyback_eligible? && sub.present? && sub.buyback_allowed?
    end

    def vendor_sourcing_applicable?
      return false if variant.blank?
      return false if used_like?
      return false if BLOCKING_PRODUCT_TYPES.include?(product&.product_type)
      return false unless variant.orderable?

      true
    end

    def purchasing_block_reason(context: :purchase_order)
      ctx = context.to_sym
      return PURCHASING_BLOCK_MESSAGES[:used_like] if used_like? && purchasing_blocking_context?(ctx)
      return PURCHASING_BLOCK_MESSAGES[:inactive_product] if product.blank? || !product.active?
      return PURCHASING_BLOCK_MESSAGES[:inactive_variant] unless variant.active?
      return PURCHASING_BLOCK_MESSAGES[:gift_card_or_non_merchandise] if BLOCKING_PRODUCT_TYPES.include?(product.product_type)
      return PURCHASING_BLOCK_MESSAGES[:not_orderable] unless variant.orderable? if purchasing_blocking_context?(ctx)
      return PURCHASING_BLOCK_MESSAGES[:non_inventory_not_orderable] if non_inventory_blocked? if purchasing_blocking_context?(ctx)

      nil
    end

    def customer_request_block_reason(request_type:)
      type = request_type.to_s
      return CUSTOMER_REQUEST_BLOCK_MESSAGES[:special_order] if type == "special_order" && used_like?

      nil
    end

    def operational_badges
      badges = []
      badges << Badge.new(key: :new, label: "New") if new_condition?
      badges << Badge.new(key: :used_like, label: "Used-like") if used_like?
      badges << Badge.new(key: :remainder, label: "Remainder") if remainder?
      badges << Badge.new(key: :vendor_orderable, label: "Vendor-orderable") if vendor_orderable?
      badges << Badge.new(key: :not_vendor_orderable, label: "Not vendor-orderable") if used_like? || !vendor_orderable?
      badges << Badge.new(key: :buyback_eligible, label: "Buyback eligible") if condition&.buyback_eligible?
      badges << Badge.new(key: :reservable, label: "Reservable") if customer_reservable?
      badges.uniq { |badge| badge.key }
    end

    def used_not_vendor_orderable_info
      USED_NOT_VENDOR_ORDERABLE_INFO if used_like?
    end

    def vendor_sourcing_not_applicable_message
      VENDOR_SOURCING_NOT_APPLICABLE if used_like?
    end

    private

    attr_reader :variant

    def condition
      variant&.condition
    end

    def product
      variant&.product
    end

    def remainder?
      condition&.condition_key == "remainder"
    end

    def non_inventory_blocked?
      product&.product_type == "non_inventory" && !variant.orderable?
    end

    def purchasing_blocking_context?(context)
      %i[purchase_order purchase_order_submit tbo].include?(context)
    end
  end
end
