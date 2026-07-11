# frozen_string_literal: true

module Products
  class FormatEligibility
    class << self
      def eligible_formats(catalog_item_type:, digital: nil)
        return Format.none if catalog_item_type.blank?

        normalized_type = ItemKindNormalizer.normalize_legacy_catalog_item_type(catalog_item_type)
        scoped = Format.active_records
                       .where(catalog_item_type: normalized_type)
                       .or(Format.active_records.where(catalog_item_type: nil, format_key: legacy_format_keys_for(normalized_type)))

        return scoped.ordered_for_display if digital.nil?

        scoped.select { |format| eligible_for_digital?(format, digital) }
              .then { |formats| Format.where(id: formats.map(&:id)).ordered_for_display }
      end

      def eligible_for_digital?(format, digital)
        return true if format.digital.nil?

        format.digital == digital
      end

      def legacy_format_keys_for(catalog_item_type)
        case catalog_item_type
        when "book"
          %w[hardcover trade_paperback mass_market_paperback audiobook_digital]
        when "recorded_music"
          %w[compact_disc]
        when "videorecording"
          %w[dvd]
        when "periodical"
          %w[magazine]
        when "calendar"
          %w[calendar]
        when "sideline"
          %w[sideline]
        else
          []
        end
      end
    end
  end
end
