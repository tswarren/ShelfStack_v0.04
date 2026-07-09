# frozen_string_literal: true

module Products
  class ItemKindNormalizer
    STAFF_ITEM_KINDS = %w[
      book recorded_music videorecording game periodical calendar sideline other service non_inventory
    ].freeze

    STAFF_LABELS = {
      "book" => "Book",
      "recorded_music" => "Recorded Music",
      "videorecording" => "Video",
      "game" => "Video Game",
      "periodical" => "Periodical",
      "calendar" => "Calendar",
      "sideline" => "Sideline",
      "other" => "Other",
      "service" => "Service",
      "non_inventory" => "Non-Inventory Item"
    }.freeze

    class << self
      def staff_item_kind_for(product:, staff_item_kind: nil)
        return staff_item_kind.to_s if staff_item_kind.present? && STAFF_ITEM_KINDS.include?(staff_item_kind.to_s)

        infer_staff_item_kind(product)
      end

      def staff_label(staff_item_kind)
        STAFF_LABELS.fetch(staff_item_kind.to_s, staff_item_kind.to_s.humanize)
      end

      def catalog_item_type_for(staff_item_kind)
        case staff_item_kind.to_s
        when "service", "non_inventory", "other"
          "other"
        else
          staff_item_kind.to_s
        end
      end

      def normalize_legacy_catalog_item_type(catalog_item_type)
        case catalog_item_type.to_s
        when "audiobook", "ebook"
          "book"
        else
          catalog_item_type.to_s
        end
      end

      def infer_staff_item_kind(product)
        return "book" if product.catalog_item_type.in?(%w[audiobook ebook])

        if product.catalog_item_type == "other"
          return "service" if product.product_type == "service"
          return "non_inventory" if product.product_type == "non_inventory"
        end

        type = product.catalog_item_type.to_s
        STAFF_ITEM_KINDS.include?(type) ? type : "other"
      end

      def staff_item_kind_from_catalog_item_type(catalog_item_type, product_type: nil)
        normalized = normalize_legacy_catalog_item_type(catalog_item_type)
        return "book" if normalized == "book"
        return "service" if normalized == "other" && product_type == "service"
        return "non_inventory" if normalized == "other" && product_type == "non_inventory"

        STAFF_ITEM_KINDS.include?(normalized) ? normalized : "other"
      end
    end
  end
end
