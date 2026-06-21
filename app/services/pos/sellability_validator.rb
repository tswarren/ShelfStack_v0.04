# frozen_string_literal: true

module Pos
  class SellabilityValidator
    Error = Class.new(StandardError)
    Warning = Data.define(:code, :message)

    def self.validate!(transaction, confirmed_inactive: false)
      new(transaction, confirmed_inactive:).validate!
    end

    def self.warnings_for(transaction)
      new(transaction).warnings
    end

    def initialize(transaction, confirmed_inactive: false)
      @transaction = transaction
      @confirmed_inactive = confirmed_inactive
    end

    def validate!
      transaction.pos_transaction_lines.each do |line|
        next unless line.variant_line?
        next if line.product_variant.blank?

        variant = line.product_variant
        product = variant.product

        if variant.sub_department.blank?
          raise Error, "Variant #{variant.sku} has no subdepartment assigned."
        end

        defaults = ClassificationDefaultsResolver.for(variant:, store: transaction.store, date: business_date)
        if defaults.tax_category.blank?
          raise Error, "Variant #{variant.sku} has no resolvable tax category."
        end

        TaxRateLookup.call(store: transaction.store, tax_category: defaults.tax_category, date: business_date)

        if (!variant.active? || !product.active?) && !confirmed_inactive
          raise Error, "Variant #{variant.sku} is inactive; confirmation required."
        end

        check_reserved_stock!(line, variant)
      end
    end

    def warnings
      transaction.pos_transaction_lines.filter_map do |line|
        next unless line.variant_line?
        next if line.product_variant.blank?

        variant = line.product_variant
        product = variant.product
        next if variant.active? && product.active?

        Warning.new(code: :inactive_sell, message: "Variant #{variant.sku} or its product is inactive.")
      end
    end

    private

    attr_reader :transaction, :confirmed_inactive

    def business_date
      transaction.business_date || Date.current
    end

    def check_reserved_stock!(line, variant)
      return if line.inventory_reservation_id.present?

      reserved = Inventory::Availability.reserved(store: transaction.store, variant: variant)
      return if reserved.zero?

      available = Inventory::Availability.available(store: transaction.store, variant: variant)
      qty = line.quantity.abs
      return if qty <= available

      raise Error, "Variant #{variant.sku} has #{reserved} reserved; use reservation pickup or override."
    end
  end
end
