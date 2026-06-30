# frozen_string_literal: true

module ExternalCatalog
  class MetadataMapper
    def self.catalog_attributes(candidate:)
      product_attributes(candidate:)
    end

    def self.product_attributes(candidate:)
      new(candidate:).product_attributes
    end

    def initialize(candidate:)
      @candidate = candidate
    end

    def product_attributes
      {
        catalog_item_type: "book",
        title: @candidate.title,
        creators: format_creators(authors_list),
        publisher: publisher_name,
        publication_date: parse_publication_date,
        publication_status: "active",
        page_count: @candidate.pages,
        language_code: language_value,
        description: plain_text_description,
        height: height_value,
        width: width_value,
        depth: depth_value,
        dimension_units: dimension_units_value,
        weight: weight_value,
        weight_units: weight_units_value,
        themes: format_themes(subjects_list),
        active: true
      }.compact
    end

    def authors_list
      if @candidate.respond_to?(:authors_snapshot)
        @candidate.authors_snapshot
      else
        @candidate.authors || []
      end
    end

    def subjects_list
      if @candidate.respond_to?(:subjects_snapshot)
        @candidate.subjects_snapshot
      else
        @candidate.subjects || []
      end
    end

    def language_value
      if @candidate.respond_to?(:language_snapshot)
        @candidate.language_snapshot
      else
        @candidate.language
      end
    end

    def publication_date_value
      if @candidate.respond_to?(:date_published_snapshot)
        @candidate.date_published_snapshot
      else
        @candidate.date_published
      end
    end

    def dimensions_snapshot
      if @candidate.respond_to?(:dimensions_snapshot)
        @candidate.dimensions_snapshot
      else
        @candidate.dimensions || {}
      end
    end

    private

    def publisher_name
      snapshot = @candidate.publisher_snapshot
      snapshot["name"].presence || snapshot[:name].presence
    end

    def format_creators(authors)
      authors.filter_map do |author|
        formatted = AuthorNameFormatter.format(author)
        formatted.presence
      end.join("; ")
    end

    def format_themes(subjects)
      seen = {}
      subjects.filter_map do |subject|
        value = subject.to_s.strip
        next if value.blank?

        key = value.downcase
        next if seen[key]

        seen[key] = true
        value
      end.join("; ")
    end

    def parse_publication_date
      value = publication_date_value.to_s.strip
      return nil if value.blank?

      return Date.new(value.to_i, 1, 1) if value.match?(/\A[0-9]{4}\z/)

      Date.parse(value)
    rescue ArgumentError, Date::Error
      nil
    end

    def plain_text_description
      synopsis = if @candidate.respond_to?(:synopsis)
                   @candidate.synopsis
      else
                   nil
      end
      HtmlToPlainText.call(synopsis)
    end

    def height_value
      dimension_value("height")
    end

    def width_value
      dimension_value("width")
    end

    def depth_value
      dimension_value("depth")
    end

    def dimension_units_value
      dimensions_snapshot["dimension_units"] || dimensions_snapshot[:dimension_units]
    end

    def weight_value
      dimension_value("weight")
    end

    def weight_units_value
      dimensions_snapshot["weight_units"] || dimensions_snapshot[:weight_units]
    end

    def dimension_value(key)
      value = dimensions_snapshot[key] || dimensions_snapshot[key.to_sym]
      return nil if value.blank?

      value.to_d.round(2)
    end
  end
end
