# frozen_string_literal: true

class CatalogIdentifierService
  class IdentifierError < StandardError; end

  STANDARD_TYPES = CatalogItemIdentifier::STANDARD_TYPES
  LOCAL_PREFIX = "L"

  def self.add_identifier!(catalog_item:, identifier_type:, value:, primary: false, actor: nil, source: "manual")
    identifier_type = identifier_type.to_s
    raise IdentifierError, "Invalid identifier type" unless CatalogItemIdentifier::IDENTIFIER_TYPES.include?(identifier_type)

    CatalogItem.transaction do
      if identifier_type == "isbn10"
        add_isbn10!(catalog_item:, value:, actor:, source:)
      else
        normalized = normalize_value(identifier_type, value)
        validation = validate_standard_identifier(identifier_type, normalized)

        identifier = catalog_item.catalog_item_identifiers.create!(
          identifier_type: identifier_type,
          identifier_value: preserve_display_value(identifier_type, value, normalized),
          normalized_identifier: normalized,
          primary_identifier: false,
          valid_check_digit: validation[:valid_check_digit],
          validation_message: validation[:validation_message],
          source: source,
          active: true
        )

        set_primary!(identifier:, actor: actor) if primary
        identifier
      end
    end
  end

  def self.generate_local!(catalog_item:, actor: nil)
    CatalogItem.transaction do
      normalized = next_local_identifier
      identifier = catalog_item.catalog_item_identifiers.create!(
        identifier_type: "local",
        identifier_value: normalized,
        normalized_identifier: normalized,
        primary_identifier: false,
        valid_check_digit: nil,
        validation_message: nil,
        source: "local_generated",
        active: true
      )

      if catalog_item.primary_identifier.blank?
        set_primary!(identifier:, actor: actor)
      end

      if actor.present?
        AuditEvents.record!(
          actor: actor,
          event_name: "catalog_item_identifier.local_generated",
          auditable: identifier,
          details: {
            "normalized_identifier" => normalized,
            "catalog_item_id" => catalog_item.id
          }
        )
      end

      identifier
    end
  end

  def self.set_primary!(identifier:, actor: nil)
    CatalogItem.transaction do
      catalog_item = identifier.catalog_item
      previous = catalog_item.primary_identifier

      catalog_item.catalog_item_identifiers.active_records.where(primary_identifier: true)
                    .where.not(id: identifier.id)
                    .find_each { |record| record.update!(primary_identifier: false) }

      identifier.update!(primary_identifier: true, active: true)

      if actor.present?
        AuditEvents.record!(
          actor: actor,
          event_name: "catalog_item_identifier.primary_changed",
          auditable: identifier,
          details: {
            "from" => previous&.normalized_identifier,
            "to" => identifier.normalized_identifier
          }
        )
      end

      identifier
    end
  end

  def self.update_identifier!(identifier:, value:, actor: nil)
    raise IdentifierError, "Identifier value is required" if value.blank?

    CatalogItem.transaction do
      identifier_type = identifier.identifier_type
      normalized = normalize_value(identifier_type, value)
      validation = validate_standard_identifier(identifier_type, normalized)

      identifier.update!(
        identifier_value: preserve_display_value(identifier_type, value, normalized),
        normalized_identifier: normalized,
        valid_check_digit: validation[:valid_check_digit],
        validation_message: validation[:validation_message],
        active: true
      )

      if actor.present?
        AuditEvents.record!(
          actor: actor,
          event_name: "catalog_item_identifier.updated",
          auditable: identifier,
          details: {
            "identifier_type" => identifier_type,
            "normalized_identifier" => normalized
          }
        )
      end

      identifier
    end
  end

  def self.remove_identifier!(identifier:, actor: nil)
    CatalogItem.transaction do
      catalog_item = identifier.catalog_item
      active_identifiers = catalog_item.catalog_item_identifiers.active_records
      raise IdentifierError, "Cannot remove the only active identifier" if active_identifiers.count <= 1

      if identifier.primary_identifier?
        replacement = active_identifiers.where.not(id: identifier.id).order(:id).first
        raise IdentifierError, "Cannot remove the only active identifier" unless replacement

        set_primary!(identifier: replacement, actor: actor)
      end

      identifier.inactivate!

      if actor.present?
        AuditEvents.record!(
          actor: actor,
          event_name: "catalog_item_identifier.inactivated",
          auditable: identifier,
          details: {
            "identifier_type" => identifier.identifier_type,
            "normalized_identifier" => identifier.normalized_identifier
          }
        )
      end

      identifier
    end
  end

  def self.normalize_preview(identifier_type, value)
    identifier_type = identifier_type.to_s
    return normalize_publisher_number(value) if identifier_type == "publisher_number"
    return value.to_s.strip if identifier_type == "local"

    normalize_standard_digits(value)
  end

  def self.validation_preview(identifier_type:, value:)
    identifier_type = identifier_type.to_s
    trimmed = value.to_s.strip
    return { normalized: "—", valid: nil, message: nil } if trimmed.blank?

    if identifier_type == "publisher_number"
      return {
        normalized: normalize_publisher_number(trimmed),
        valid: nil,
        message: nil
      }
    end

    return { normalized: trimmed, valid: nil, message: nil } if identifier_type == "local"

    normalized = normalize_standard_digits(trimmed)
    validation = validate_standard_identifier(identifier_type, normalized)

    {
      normalized: normalized.presence || "—",
      valid: validation[:valid_check_digit],
      message: validation[:validation_message]
    }
  end

  def self.add_isbn10!(catalog_item:, value:, actor:, source:)
    normalized = normalize_standard_digits(value)
    validation = validate_isbn10(normalized)

    isbn10 = catalog_item.catalog_item_identifiers.create!(
      identifier_type: "isbn10",
      identifier_value: preserve_display_value("isbn10", value, normalized),
      normalized_identifier: normalized,
      primary_identifier: false,
      valid_check_digit: validation[:valid_check_digit],
      validation_message: validation[:validation_message],
      source: source,
      active: true
    )

    isbn13_normalized = convert_isbn10_to_isbn13(normalized)
    isbn13_validation = validate_isbn13(isbn13_normalized)

    isbn13 = catalog_item.catalog_item_identifiers.find_or_initialize_by(
      identifier_type: "isbn13",
      normalized_identifier: isbn13_normalized
    )
    isbn13.assign_attributes(
      identifier_value: isbn13_normalized,
      primary_identifier: false,
      valid_check_digit: isbn13_validation[:valid_check_digit],
      validation_message: isbn13_validation[:validation_message],
      source: "isbn10_converted",
      active: true
    )
    isbn13.save!

    set_primary!(identifier: isbn13, actor: actor)

    if actor.present?
      AuditEvents.record!(
        actor: actor,
        event_name: "catalog_item_identifier.isbn10_converted",
        auditable: isbn13,
        details: {
          "isbn10" => normalized,
          "isbn13" => isbn13_normalized
        }
      )
    end

    isbn10
  end
  private_class_method :add_isbn10!

  def self.normalize_value(identifier_type, value)
    case identifier_type
    when "publisher_number" then normalize_publisher_number(value)
    when "local" then value.to_s.strip.upcase
    else normalize_standard_digits(value)
    end
  end
  private_class_method :normalize_value

  def self.preserve_display_value(identifier_type, value, normalized)
    case identifier_type
    when "publisher_number" then value.to_s.strip
    when *STANDARD_TYPES then normalized
    else value.to_s.strip
    end
  end
  private_class_method :preserve_display_value

  def self.normalize_standard_digits(value)
    cleaned = value.to_s.strip.upcase
    cleaned = cleaned.gsub(/[^0-9X]/, "")
    cleaned.sub(/X\z/, "X")
  end
  private_class_method :normalize_standard_digits

  def self.normalize_publisher_number(value)
    value.to_s.gsub(/[^A-Za-z0-9]/, "").upcase
  end
  private_class_method :normalize_publisher_number

  def self.validate_standard_identifier(identifier_type, normalized)
    case identifier_type
    when "isbn10" then validate_isbn10(normalized)
    when "isbn13" then validate_isbn13(normalized)
    when "ean", "upc", "gtin" then validate_gtin_family(normalized)
    else { valid_check_digit: nil, validation_message: nil }
    end
  end
  private_class_method :validate_standard_identifier

  def self.validate_isbn10(normalized)
    return invalid_result("ISBN-10 must be 10 characters") unless normalized.match?(/\A[0-9]{9}[0-9X]\z/)

    sum = 0
    normalized.chars.each_with_index do |char, index|
      digit = char == "X" ? 10 : char.to_i
      sum += (10 - index) * digit
    end

    valid = (sum % 11).zero?
    valid ? valid_result : invalid_result("ISBN-10 check digit is invalid")
  end
  private_class_method :validate_isbn10

  def self.validate_isbn13(normalized)
    return invalid_result("ISBN-13 must be 13 digits") unless normalized.match?(/\A[0-9]{13}\z/)

    valid = gtin_check_digit(normalized[0, 12]) == normalized[-1].to_i
    valid ? valid_result : invalid_result("ISBN-13 check digit is invalid")
  end
  private_class_method :validate_isbn13

  def self.validate_gtin_family(normalized)
    return invalid_result("Identifier must contain digits only") unless normalized.match?(/\A[0-9]+\z/)
    return invalid_result("GTIN family identifier has invalid length") unless [ 8, 12, 13, 14 ].include?(normalized.length)

    valid = gtin_check_digit(normalized[0..-2]) == normalized[-1].to_i
    valid ? valid_result : invalid_result("Check digit is invalid")
  end
  private_class_method :validate_gtin_family

  def self.gtin_check_digit(body)
    sum = 0
    body.chars.reverse.each_with_index do |char, index|
      weight = index.even? ? 3 : 1
      sum += char.to_i * weight
    end
    (10 - (sum % 10)) % 10
  end
  private_class_method :gtin_check_digit

  def self.convert_isbn10_to_isbn13(isbn10)
    body = "978#{isbn10[0, 9]}"
    "#{body}#{gtin_check_digit(body)}"
  end
  private_class_method :convert_isbn10_to_isbn13

  def self.next_local_identifier
    latest = CatalogItemIdentifier.where(identifier_type: "local")
                                  .order(normalized_identifier: :desc)
                                  .limit(1)
                                  .pick(:normalized_identifier)
    sequence = latest.to_s.delete_prefix(LOCAL_PREFIX).to_i + 1
    format("#{LOCAL_PREFIX}%09d", sequence)
  end
  private_class_method :next_local_identifier

  def self.valid_result
    { valid_check_digit: true, validation_message: nil }
  end
  private_class_method :valid_result

  def self.invalid_result(message)
    { valid_check_digit: false, validation_message: message }
  end
  private_class_method :invalid_result
end
