# frozen_string_literal: true

module ExternalCatalog
  BookCandidate = Data.define(
    :source_key,
    :external_identifier,
    :isbn10,
    :isbn13,
    :title,
    :subtitle,
    :authors,
    :publisher,
    :date_published,
    :binding,
    :language,
    :pages,
    :msrp_cents,
    :currency_code,
    :image_url,
    :synopsis,
    :excerpt,
    :subjects,
    :dewey_decimal,
    :dimensions,
    :other_isbns,
    :raw_payload
  ) do
    def authors_snapshot
      authors || []
    end

    def publisher_snapshot
      publisher.is_a?(Hash) ? publisher : { "name" => publisher.to_s.presence }.compact
    end

    def subjects_snapshot
      subjects || []
    end

    def dimensions_snapshot
      dimensions || {}
    end

    def other_isbns_snapshot
      other_isbns || []
    end
  end
end
