# frozen_string_literal: true

module IngramCatalogImport
  Row = Struct.new(
    :row_number,
    :product_code,
    :ean,
    :product_name,
    :contributor,
    :product_type,
    :format,
    :supplier,
    :pub_date,
    :series,
    :bisac_category,
    :us_srp_cents,
    :weight,
    keyword_init: true
  ) do
    def identifier_label
      ean.presence || product_code.presence || "—"
    end

    def to_preview_hash
      {
        row_number: row_number,
        product_code: product_code,
        ean: ean,
        product_name: product_name,
        format: format,
        us_srp_cents: us_srp_cents
      }
    end

    def valid?
      product_name.present? && us_srp_cents.present? && (ean.present? || product_code.present?)
    end
  end
end
