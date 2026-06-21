# frozen_string_literal: true

module ExternalCatalog
  class LookupByIsbn
    Outcome = Struct.new(:status, :normalized_isbn, :catalog_item, :lookup_result, :request, :message, keyword_init: true)

    def self.call(isbn:, actor:, source: nil, client: nil)
      new(isbn:, actor:, source:, client:).call
    end

    def initialize(isbn:, actor:, source: nil, client: nil)
      @isbn = isbn.to_s.strip
      @actor = actor
      @source = source || ExternalDataSource.find_by!(source_key: "isbndb")
      @client = client || Provider::IsbndbClient.new
    end

    def call
      normalized = normalize_isbn(@isbn)
      if normalized.blank?
        return Outcome.new(status: :invalid, message: "Enter a valid ISBN.")
      end

      local = LocalIsbnMatch.call(isbn: normalized)
      if local.matched?
        record_local_match!(local)
        return Outcome.new(
          status: :local_match,
          normalized_isbn: local.normalized_isbn,
          catalog_item: local.catalog_item
        )
      end

      started_at = Time.current
      path = "/book/#{normalized}"
      response = @client.fetch_book(normalized)

      if response.error.present?
        persisted = persist_failure!(
          normalized:, path:, started_at:, status: "failed",
          response_status_code: response.status_code,
          error_message: response.error
        )
        record_audit!("external_lookup.failed", persisted.request, normalized)
        return failure_outcome(:failed, persisted, "Lookup failed: #{response.error}")
      end

      if response.rate_limited?
        persisted = persist_failure!(
          normalized:, path:, started_at:, status: "rate_limited",
          response_status_code: 429, error_code: "rate_limited",
          error_message: "ISBNdb rate limit reached."
        )
        record_audit!("external_lookup.rate_limited", persisted.request, normalized)
        return failure_outcome(:rate_limited, persisted, "ISBNdb rate limit reached. Try again later.")
      end

      if response.not_found?
        persisted = persist_failure!(
          normalized:, path:, started_at:, status: "not_found",
          response_status_code: 404, error_code: "not_found",
          error_message: "No record found for this ISBN."
        )
        record_audit!("external_lookup.not_found", persisted.request, normalized)
        return failure_outcome(:not_found, persisted, "No external record found for this ISBN.")
      end

      unless response.success?
        persisted = persist_failure!(
          normalized:, path:, started_at:, status: "failed",
          response_status_code: response.status_code,
          error_message: "Unexpected response (#{response.status_code})."
        )
        record_audit!("external_lookup.failed", persisted.request, normalized)
        return failure_outcome(:failed, persisted, "Lookup failed with status #{response.status_code}.")
      end

      candidate = Provider::IsbndbNormalizer.call(payload: response.parsed_json, source_key: @source.source_key)
      duplicate = DuplicateDetector.call(isbn13: candidate.isbn13, isbn10: candidate.isbn10)
      persisted = PersistLookupResult.call(
        source: @source,
        actor: @actor,
        query: @isbn,
        normalized_query: normalized,
        lookup_type: "isbn",
        request_path: path,
        status: "completed",
        response_status_code: 200,
        candidate: candidate,
        local_catalog_item: duplicate.catalog_item,
        started_at: started_at
      )
      record_audit!("external_lookup.completed", persisted.request, normalized)

      Outcome.new(
        status: :completed,
        normalized_isbn: normalized,
        lookup_result: persisted.lookup_result,
        request: persisted.request,
        catalog_item: duplicate.catalog_item
      )
    end

    private

    def normalize_isbn(value)
      CatalogIdentifierService.normalize_preview("isbn13", value)
    rescue CatalogIdentifierService::IdentifierError
      nil
    end

    def record_local_match!(local)
      record_audit!(
        "external_lookup.local_match",
        local.catalog_item,
        local.normalized_isbn
      )
    end

    def record_audit!(event_name, auditable, normalized_isbn = nil)
      details = {}
      details["normalized_isbn"] = normalized_isbn if normalized_isbn.present?
      AuditEvents.record!(
        actor: @actor,
        event_name: event_name,
        auditable: auditable,
        details: details
      )
    end

    def persist_failure!(normalized:, path:, started_at:, status:, response_status_code:, error_message:, error_code: nil)
      PersistLookupResult.call(
        source: @source,
        actor: @actor,
        query: @isbn,
        normalized_query: normalized,
        lookup_type: "isbn",
        request_path: path,
        status: status,
        response_status_code: response_status_code,
        error_code: error_code,
        error_message: error_message,
        started_at: started_at
      )
    end

    def failure_outcome(status, persisted, message)
      Outcome.new(
        status: status,
        normalized_isbn: persisted.request.normalized_query,
        lookup_result: persisted.lookup_result,
        request: persisted.request,
        message: message
      )
    end
  end
end
