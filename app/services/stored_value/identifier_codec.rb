# frozen_string_literal: true

module StoredValue
  class IdentifierCodec
    BODY_LENGTH = 15
    CHARSET = ("0".."9").to_a.freeze

    class InvalidIdentifierError < StandardError; end

    def self.generate
      loop do
        body = Array.new(BODY_LENGTH) { CHARSET.sample(random: SecureRandom) }.join
        value = "#{body}#{mod10_check_digit(body)}"
        next if StoredValueIdentifier.active_records.exists?(lookup_digest: digest(value))

        return {
          normalized_value: normalize(value),
          lookup_digest: digest(value),
          display_value_masked: mask(value)
        }
      end
    end

    def self.normalize(raw)
      raw.to_s.gsub(/[\s-]/, "").upcase
    end

    def self.digest(raw)
      Digest::SHA256.hexdigest(normalize(raw))
    end

    def self.format_display(raw)
      normalized = normalize(raw)
      return normalized if normalized.length < 8

      normalized.scan(/.{1,4}/).join("-")
    end

    def self.mask(raw)
      normalized = normalize(raw)
      return "****" if normalized.length < 4

      "****#{normalized[-4, 4]}"
    end

    def self.valid?(raw)
      normalized = normalize(raw)
      return false unless normalized.match?(/\A[0-9]+\z/)
      return false unless normalized.length == BODY_LENGTH + 1

      mod10_check_digit(normalized[0, BODY_LENGTH]) == normalized[-1].to_i
    end

    def self.validate!(raw)
      normalized = normalize(raw)
      raise InvalidIdentifierError, "Identifier is required" if normalized.blank?
      raise InvalidIdentifierError, "Identifier must be numeric" unless normalized.match?(/\A[0-9]+\z/)
      raise InvalidIdentifierError, "Identifier has invalid length" unless normalized.length == BODY_LENGTH + 1
      raise InvalidIdentifierError, "Check digit is invalid" unless valid?(raw)

      normalized
    end

    def self.lookup(raw)
      StoredValueIdentifier.active_records.find_by(lookup_digest: digest(raw))
    end

    def self.mod10_check_digit(body)
      sum = 0
      body.chars.reverse.each_with_index do |char, index|
        weight = index.even? ? 3 : 1
        sum += char.to_i * weight
      end
      (10 - (sum % 10)) % 10
    end
    private_class_method :mod10_check_digit
  end
end
