# frozen_string_literal: true

module ExternalCatalog
  class PersistLookupResult
    Result = Struct.new(:request, :lookup_result, keyword_init: true)

    def self.call(source:, actor:, query:, normalized_query:, lookup_type:, request_path:, status:,
                  response_status_code: nil, error_code: nil, error_message: nil,
                  candidate: nil, local_catalog_item: nil, started_at: Time.current)
      new(
        source: source,
        actor: actor,
        query: query,
        normalized_query: normalized_query,
        lookup_type: lookup_type,
        request_path: request_path,
        status: status,
        response_status_code: response_status_code,
        error_code: error_code,
        error_message: error_message,
        candidate: candidate,
        local_catalog_item: local_catalog_item,
        started_at: started_at
      ).call
    end

    def initialize(source:, actor:, query:, normalized_query:, lookup_type:, request_path:, status:,
                   response_status_code:, error_code:, error_message:, candidate:, local_catalog_item:, started_at:)
      @source = source
      @actor = actor
      @query = query
      @normalized_query = normalized_query
      @lookup_type = lookup_type
      @request_path = request_path
      @status = status
      @response_status_code = response_status_code
      @error_code = error_code
      @error_message = error_message
      @candidate = candidate
      @local_catalog_item = local_catalog_item
      @started_at = started_at
    end

    def call
      ExternalLookupRequest.transaction do
        request = ExternalLookupRequest.create!(
          external_data_source: @source,
          lookup_type: @lookup_type,
          query: @query,
          normalized_query: @normalized_query,
          request_path: @request_path,
          request_params_json: {},
          status: @status,
          response_status_code: @response_status_code,
          error_code: @error_code,
          error_message: @error_message,
          requested_by_user: @actor,
          started_at: @started_at,
          completed_at: Time.current
        )

        lookup_result = nil
        if @candidate.present?
          lookup_result = request.create_external_lookup_result!(
            source_key: @candidate.source_key,
            external_identifier: @candidate.external_identifier,
            isbn10: @candidate.isbn10,
            isbn13: @candidate.isbn13,
            title: @candidate.title,
            subtitle: @candidate.subtitle,
            authors_snapshot: @candidate.authors_snapshot,
            publisher_snapshot: @candidate.publisher_snapshot,
            date_published_snapshot: @candidate.date_published,
            binding_snapshot: @candidate.binding,
            language_snapshot: @candidate.language,
            pages: @candidate.pages,
            msrp_cents: @candidate.msrp_cents,
            currency_code: @candidate.currency_code,
            image_url: @candidate.image_url,
            synopsis: @candidate.synopsis,
            excerpt: @candidate.excerpt,
            subjects_snapshot: @candidate.subjects_snapshot,
            dewey_decimal_snapshot: @candidate.dewey_decimal,
            dimensions_snapshot: @candidate.dimensions_snapshot,
            other_isbns_snapshot: @candidate.other_isbns_snapshot,
            raw_payload_json: @candidate.raw_payload || {},
            local_catalog_item: @local_catalog_item
          )
        end

        Result.new(request: request, lookup_result: lookup_result)
      end
    end
  end
end
