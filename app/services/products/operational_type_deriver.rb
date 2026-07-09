# frozen_string_literal: true

module Products
  class OperationalTypeDeriver
    BIBLIOGRAPHIC_DIGITAL_KINDS = %w[
      book recorded_music videorecording game audiobook ebook
    ].freeze

    class << self
      def derive(staff_item_kind:, digital: false)
        case staff_item_kind.to_s
        when "service"
          "service"
        when "non_inventory"
          "non_inventory"
        when *BIBLIOGRAPHIC_DIGITAL_KINDS
          digital ? "digital" : "physical"
        else
          "physical"
        end
      end
    end
  end
end
