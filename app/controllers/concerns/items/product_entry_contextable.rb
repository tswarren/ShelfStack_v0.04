# frozen_string_literal: true

module Items
  module ProductEntryContextable
    extend ActiveSupport::Concern

    private

    def build_product_entry_context(product, mode: nil)
      staff_item_kind = params[:staff_item_kind].presence ||
                        params.dig(:product, :staff_item_kind).presence ||
                        params.dig(:catalog_item, :staff_item_kind).presence
      if staff_item_kind.blank?
        catalog_type = params[:catalog_item_type].presence ||
                       params.dig(:product, :catalog_item_type).presence ||
                       params.dig(:catalog_item, :catalog_item_type).presence ||
                       product.catalog_item_type
        staff_item_kind = Products::ItemKindNormalizer.staff_item_kind_from_catalog_item_type(
          catalog_type,
          product_type: product.product_type
        )
      end

      digital_param =
        if params.key?(:digital)
          params[:digital]
        elsif params.dig(:product)&.key?(:digital)
          params.dig(:product, :digital)
        elsif params.dig(:catalog_item)&.key?(:digital)
          params.dig(:catalog_item, :digital)
        end
      digital = digital_param.nil? ? product.digital : ActiveModel::Type::Boolean.new.cast(digital_param)

      format_id = params[:format_id].presence ||
                  params.dig(:product, :format_id) ||
                  params.dig(:catalog_item, :format_id)
      format = format_id.present? ? Format.find_by(id: format_id) : product.format

      variation_type = params[:variation_type].presence ||
                       params.dig(:product, :variation_type).presence ||
                       params.dig(:catalog_item, :variation_type).presence ||
                       product.variation_type

      Products::EntryContext.build(
        product: product,
        staff_item_kind: staff_item_kind,
        digital: digital,
        format: format,
        variation_type: variation_type,
        mode: mode || (product.persisted? ? :edit : :new)
      )
    end

    def sanitized_product_metadata_params(product, mode: :new, item_kind_changed: false)
      entry_context = build_product_entry_context(product, mode: mode)
      raw = product_metadata_params_hash
      sanitized = Products::MetadataParamsSanitizer.sanitize(
        params: raw.merge(staff_item_kind: entry_context.staff_item_kind),
        entry_context: entry_context,
        mode: mode,
        item_kind_changed: item_kind_changed
      )
      sanitized.except(:staff_item_kind, :_classification_cleanup)
    end

    def product_metadata_params_hash
      source = params[:product].presence || params[:catalog_item]
      return {} unless source

      source = source.to_unsafe_h if source.respond_to?(:to_unsafe_h)
      source.symbolize_keys
    end

    def item_kind_changed?(product)
      raw = product_metadata_params_hash
      new_kind = raw[:staff_item_kind].presence
      return false if new_kind.blank?

      Products::ItemKindNormalizer.infer_staff_item_kind(product) != new_kind.to_s
    end

    def apply_entry_context_product_type!(product, entry_context)
      product.product_type = entry_context.operational_product_type
      product.catalog_item_type = entry_context.catalog_item_type
    end
  end
end
