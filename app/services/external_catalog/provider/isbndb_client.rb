# frozen_string_literal: true

require "cgi"
require "net/http"
require "uri"

module ExternalCatalog
  module Provider
    class IsbndbClient
      Response = Struct.new(:status_code, :body, :error, keyword_init: true) do
        def success?
          status_code == 200
        end

        def not_found?
          status_code == 404
        end

        def rate_limited?
          status_code == 429
        end

        def parsed_json
          return {} if body.blank?

          JSON.parse(body)
        rescue JSON::ParserError
          {}
        end
      end

      BASE_URL = "https://api2.isbndb.com".freeze
      OPEN_TIMEOUT = 2
      READ_TIMEOUT = 5

      def self.api_key
        Rails.application.credentials.dig(:isbndb, :api_key).presence ||
          ENV["ISBNDB_API_KEY"].presence
      end

      def initialize(base_url: BASE_URL, api_key: self.class.api_key)
        @base_url = base_url
        @api_key = api_key
      end

      def fetch_book(isbn)
        get("/book/#{CGI.escape(isbn.to_s)}")
      end

      def check_key
        get("/key")
      end

      private

      def get(path)
        raise ArgumentError, "ISBNdb API key is not configured" if @api_key.blank?

        uri = URI.parse("#{@base_url}#{path}")
        request = Net::HTTP::Get.new(uri)
        request["Authorization"] = @api_key
        request["Accept"] = "application/json"

        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                 open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
          http.request(request)
        end
        elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round

        Response.new(status_code: response.code.to_i, body: response.body, error: nil)
      rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error => e
        Response.new(status_code: nil, body: nil, error: e.message)
      rescue StandardError => e
        Response.new(status_code: nil, body: nil, error: e.message)
      end
    end
  end
end
