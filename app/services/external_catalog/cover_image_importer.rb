# frozen_string_literal: true

require "net/http"
require "uri"

module ExternalCatalog
  class CoverImageImporter
    Result = Struct.new(:attached, :message, keyword_init: true)

    OPEN_TIMEOUT = 2
    READ_TIMEOUT = 10
    MAX_REDIRECTS = 5

    def self.call(product:, url:, actor: nil)
      new(product:, url:, actor:).call
    end

    def initialize(product:, url:, actor: nil)
      @product = product
      @url = url.to_s.strip
      @actor = actor
    end

    def call
      return Result.new(attached: false, message: "Cover image URL is blank.") if @url.blank?
      return Result.new(attached: false, message: nil) if @product.cover_image.attached?

      uri = URI.parse(@url)
      response = fetch(uri)
      unless response.is_a?(Net::HTTPSuccess)
        return Result.new(attached: false, message: "Cover image download failed with status #{response.code}.")
      end

      body = response.body.b
      if body.empty?
        return Result.new(attached: false, message: "Cover image download returned an empty or invalid file.")
      end

      content_type = normalize_content_type(response.content_type.presence || Marcel::MimeType.for(body))
      unless Product::ALLOWED_COVER_IMAGE_TYPES.include?(content_type)
        return Result.new(attached: false, message: "Cover image type #{content_type} is not supported.")
      end

      if body.bytesize > Product::MAX_COVER_IMAGE_SIZE
        return Result.new(attached: false, message: "Cover image is larger than 5 MB.")
      end

      @product.cover_image.attach(
        io: StringIO.new(body),
        filename: filename_for(uri, content_type),
        content_type: content_type
      )

      unless @product.valid?
        @product.cover_image.purge
        message = @product.errors[:cover_image].presence&.join(", ") || "Cover image could not be attached."
        return Result.new(attached: false, message: message)
      end

      record_audit! if @actor.present?
      Result.new(attached: true, message: nil)
    rescue StandardError => e
      Result.new(attached: false, message: "Cover image import failed: #{e.message}")
    end

    private

    def fetch(uri, redirects_remaining: MAX_REDIRECTS)
      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = "ShelfStack/1.0"

      response = Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: OPEN_TIMEOUT,
        read_timeout: READ_TIMEOUT
      ) do |http|
        http.request(request)
      end

      if response.is_a?(Net::HTTPRedirection) && redirects_remaining.positive?
        location = response["location"]
        raise "Cover image redirect missing location header." if location.blank?

        return fetch(URI.parse(location), redirects_remaining: redirects_remaining - 1)
      end

      response
    end

    def normalize_content_type(content_type)
      type = content_type.to_s.split(";").first.strip.downcase
      type == "image/jpg" ? "image/jpeg" : type
    end

    def filename_for(uri, content_type)
      basename = File.basename(uri.path)
      return basename if basename.present? && basename != "/"

      extension = Rack::Mime::MIME_TYPES.invert[content_type] || ".jpg"
      "cover#{extension}"
    end

    def record_audit!
      AuditEvents.record!(
        actor: @actor,
        event_name: "external_lookup.cover_image_imported",
        auditable: @product,
        details: { "source_url" => @url }
      )
    end
  end
end
