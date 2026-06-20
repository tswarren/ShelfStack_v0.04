# frozen_string_literal: true

module ExternalCatalog
  class CheckProviderHealth
    Result = Struct.new(:source, :status, :message, :cached, keyword_init: true)

    CACHE_DURATION = 30.minutes

    def self.call(source:, actor: nil, force: false, client: nil)
      new(source:, actor:, force:, client:).call
    end

    def initialize(source:, actor: nil, force: false, client: nil)
      @source = source
      @actor = actor
      @force = force
      @client = client
    end

    def call
      if !@force && @source.health_check_fresh?(max_age: CACHE_DURATION)
        return Result.new(
          source: @source,
          status: @source.last_health_check_status,
          message: "Using cached health check from #{@source.last_health_check_at}.",
          cached: true
        )
      end

      client = @client || Provider::IsbndbClient.new(base_url: @source.base_url)
      response = client.check_key

      status, message, limits = interpret_response(response)
      @source.update!(
        last_health_check_at: Time.current,
        last_health_check_status: status,
        last_plan_limit_total: limits[:total],
        last_plan_limit_spent: limits[:spent],
        last_plan_limit_left: limits[:left]
      )

      if @actor.present?
        AuditEvents.record!(
          actor: @actor,
          event_name: "external_lookup.health_check",
          auditable: @source,
          details: { "status" => status, "message" => message }
        )
      end

      Result.new(source: @source, status: status, message: message, cached: false)
    end

    private

    def interpret_response(response)
      if response.error.present?
        return [ "failed", "Health check failed: #{response.error}", empty_limits ]
      end

      if response.success?
        payload = response.parsed_json
        limits = {
          total: payload["requests"].to_i,
          spent: payload["requests_used"].to_i,
          left: payload["requests_left"].to_i
        }
        return [ "ok", "ISBNdb API key is valid.", limits ]
      end

      [ "failed", "Health check returned status #{response.status_code}.", empty_limits ]
    end

    def empty_limits
      { total: nil, spent: nil, left: nil }
    end
  end
end
