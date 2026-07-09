# frozen_string_literal: true

module Products
  class EntryContext
    include ActiveModel::Model

    attr_reader :product, :staff_item_kind, :digital, :format, :variation_type, :mode,
                :field_visibility, :field_labels, :eligible_formats, :controlled_scheme,
                :operational_product_type

    def self.build(product:, staff_item_kind: nil, digital: nil, format: nil, variation_type: nil, mode: :new)
      new(
        product: product,
        staff_item_kind: staff_item_kind,
        digital: digital,
        format: format,
        variation_type: variation_type,
        mode: mode
      ).tap(&:resolve!)
    end

    def initialize(product:, staff_item_kind: nil, digital: nil, format: nil, variation_type: nil, mode: :new)
      @product = product
      @mode = mode.to_sym
      @staff_item_kind = ItemKindNormalizer.staff_item_kind_for(
        product: product,
        staff_item_kind: staff_item_kind
      )
      @digital = digital.nil? ? product.digital : digital
      @format = format || product.format
      @variation_type = variation_type || product.variation_type
    end

    def resolve!
      resolver = FieldVisibilityResolver.new(
        staff_item_kind: @staff_item_kind,
        digital: @digital,
        format: @format,
        variation_type: @variation_type,
        product_type: operational_product_type
      )
      @field_visibility = resolver.resolve
      @controlled_scheme = resolver.controlled_scheme
      @field_labels = FieldLabelResolver.labels_for(staff_item_kind: @staff_item_kind)
      @eligible_formats = FormatEligibility.eligible_formats(
        catalog_item_type: ItemKindNormalizer.catalog_item_type_for(@staff_item_kind),
        digital: @digital
      )
      @operational_product_type = OperationalTypeDeriver.derive(
        staff_item_kind: @staff_item_kind,
        digital: @digital
      )
      self
    end

    def short_form?
      @staff_item_kind.in?(%w[service non_inventory])
    end

    def visible?(field_key)
      field_visibility.fetch(field_key.to_sym) { FieldVisibilityResolver::FieldState.new(visible: false, required: false) }.visible
    end

    def required?(field_key)
      field_visibility.fetch(field_key.to_sym) { FieldVisibilityResolver::FieldState.new(visible: false, required: false) }.required
    end

    def catalog_item_type
      ItemKindNormalizer.catalog_item_type_for(@staff_item_kind)
    end
  end
end
