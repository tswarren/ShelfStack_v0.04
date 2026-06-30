# frozen_string_literal: true

class ProductIdentifierService
  class IdentifierError < StandardError; end

  LEGACY_IDENTIFIER_TYPES = %w[isbn10 isbn13 ean upc gtin publisher_number local].freeze
  LEGACY_LOCAL_PREFIX = "L"
  LEGACY_PRODUCT_SKU_PREFIX = "P"

  def self.add_identifier!(product:, validation_family:, value:, freeform_scope: nil, primary: false, actor: nil, source: "manual")
    validation_family = validation_family.to_s
    raise IdentifierError, "Invalid validation family" unless ProductIdentifier::VALIDATION_FAMILIES.include?(validation_family)

    Product.transaction do
      case validation_family
      when "isbn"
        add_isbn10!(product:, value:, actor:, source:)
      when "gtin"
        add_gtin!(product:, value:, primary:, actor:, source:)
      when "freeform"
        add_freeform!(product:, value:, freeform_scope:, primary:, actor:, source:)
      when "house"
        raise IdentifierError, "Use generate_house! for house identifiers"
      else
        raise IdentifierError, "Unsupported validation family"
      end
    end
  end

  def self.generate_house!(product:, actor: nil, source: "house_generated")
    Product.transaction do
      normalized = InternalEanAllocator.allocate!(segment: "201", purpose: "product_house")
      identifier = product.product_identifiers.create!(
        validation_family: "house",
        identifier_value: normalized,
        normalized_identifier: normalized,
        primary_identifier: false,
        valid_check_digit: true,
        validation_message: nil,
        source: source,
        active: true
      )

      if product.primary_identifier.blank?
        set_primary!(identifier:, actor: actor)
      end

      record_audit!(
        actor: actor,
        event_name: "product_identifier.house_generated",
        identifier: identifier,
        source: source,
        details: {
          "normalized_identifier" => normalized,
          "segment" => "201"
        }
      )
      identifier
    end
  end

  def self.add_house_from_value!(product:, value:, primary:, actor:, source:)
    normalized = normalize_standard_digits(value)
    validation = validate_house_value!(normalized)
    ensure_unique_gtin!(product:, normalized:)

    identifier = product.product_identifiers.create!(
      validation_family: "house",
      identifier_value: normalized,
      normalized_identifier: normalized,
      primary_identifier: false,
      valid_check_digit: validation[:valid_check_digit],
      validation_message: validation[:validation_message],
      source: source,
      active: true
    )

    set_primary!(identifier:, actor: actor, source: source) if primary || product.primary_identifier.blank?

    record_audit!(
      actor: actor,
      event_name: "product_identifier.created",
      identifier: identifier,
      source: source
    )
    identifier
  end
  private_class_method :add_house_from_value!

  def self.set_primary!(identifier:, actor: nil, source: "manual")
    Product.transaction do
      product = identifier.product
      previous = product.primary_identifier

      product.product_identifiers.active_records.where(primary_identifier: true)
             .where.not(id: identifier.id)
             .find_each { |record| record.update!(primary_identifier: false) }

      identifier.update!(primary_identifier: true, active: true)
      sync_product_sku_cache!(product)

      record_audit!(
        actor: actor,
        event_name: "product_identifier.primary_changed",
        identifier: identifier,
        source: source,
        details: {
          "previous_value" => previous&.normalized_identifier,
          "new_value" => identifier.normalized_identifier,
          "primary_identifier" => true
        }
      )
      identifier
    end
  end

  def self.update_identifier!(identifier:, value:, actor: nil, source: "manual")
    raise IdentifierError, "Identifier value is required" if value.blank?

    Product.transaction do
      case identifier.validation_family
      when "isbn"
        raise IdentifierError, "ISBN alternates must be recreated via add_identifier!"
      when "gtin"
        update_gtin_like!(identifier:, value:, actor:, source:)
      when "house"
        update_house!(identifier:, value:, actor:, source:)
      when "freeform"
        update_freeform!(identifier:, value:, actor:, source:)
      else
        raise IdentifierError, "Unsupported validation family"
      end
    end
  end

  def self.inactivate_identifier!(identifier:, actor: nil, source: "manual")
    Product.transaction do
      product = identifier.product
      active_identifiers = product.product_identifiers.active_records
      raise IdentifierError, "Cannot remove the only active identifier" if active_identifiers.count <= 1

      if identifier.primary_identifier?
        replacement = active_identifiers.where.not(id: identifier.id).order(:id).first
        raise IdentifierError, "Cannot remove the only active identifier" unless replacement

        set_primary!(identifier: replacement, actor: actor, source: source)
      end

      identifier.inactivate!
      sync_product_sku_cache!(product)

      record_audit!(
        actor: actor,
        event_name: "product_identifier.inactivated",
        identifier: identifier,
        source: source,
        details: identifier_payload(identifier)
      )
      identifier
    end
  end

  def self.validation_preview(validation_family:, value:, freeform_scope: nil)
    validation_family = validation_family.to_s
    trimmed = value.to_s.strip
    return { normalized: "—", valid: nil, message: nil } if trimmed.blank?

    case validation_family
    when "freeform"
      normalized = normalize_freeform(trimmed, freeform_scope)
      { normalized: normalized.presence || "—", valid: nil, message: nil }
    when "isbn"
      normalized = normalize_standard_digits(trimmed)
      validation = validate_isbn10(normalized)
      {
        normalized: normalized.presence || "—",
        valid: validation[:valid_check_digit],
        message: validation[:validation_message]
      }
    when "gtin", "house"
      normalized = normalize_standard_digits(trimmed)
      validation = validate_gtin_family(normalized)
      {
        normalized: normalized.presence || "—",
        valid: validation[:valid_check_digit],
        message: validation[:validation_message]
      }
    else
      { normalized: "—", valid: nil, message: nil }
    end
  end

  def self.lookup_candidates(value)
    digits = normalize_standard_digits(value)
    return [] if digits.blank?

    candidates = [ digits ]
    candidates << convert_isbn10_to_isbn13(digits) if digits.length == 10
    candidates.uniq
  end

  def self.lookup_digit_prefix(value)
    normalize_standard_digits(value)
  end

  def self.sync_product_sku_cache!(product)
    primary = product.primary_identifier
    cache_value = primary&.normalized_identifier
    return if cache_value.blank?
    return if product.sku == cache_value
    return if Product.where.not(id: product.id).exists?(sku: cache_value)

    product.update!(sku: cache_value)
  end

  def self.sync_from_product_sku!(product:, actor: nil, source: "product_sku_sync")
    sku = product.sku.to_s.strip
    return product if sku.blank?

    family, freeform_scope = classify_product_sku(sku)
    return product if family.blank?

    normalized = normalize_sku_for_family(sku, family, freeform_scope)

    Product.transaction do
      matching = product.product_identifiers.active_records.find_by(normalized_identifier: normalized)
      if matching
        set_primary!(identifier: matching, actor: actor, source: source) unless matching.primary_identifier?
        sync_product_sku_cache!(product)
        return matching
      end

      primary = product.primary_identifier
      if primary && identifier_accepts_sku?(primary, family)
        update_identifier!(identifier: primary, value: sku, actor: actor, source: source)
        sync_product_sku_cache!(product)
        return primary.reload
      end

      identifier = case family
      when "gtin"
        add_gtin!(product: product, value: sku, primary: true, actor: actor, source: source)
      when "isbn"
        add_isbn10!(product: product, value: sku, actor: actor, source: source)
      when "house"
        add_house_from_value!(product: product, value: sku, primary: true, actor: actor, source: source)
      when "freeform"
        add_freeform!(product: product, value: sku, freeform_scope: freeform_scope, primary: true, actor: actor, source: source)
      end
      sync_product_sku_cache!(product)
      identifier
    end
  end

  def self.classify_product_sku(sku)
    normalized = sku.to_s.strip.upcase
    if normalized.start_with?(LEGACY_LOCAL_PREFIX)
      [ "freeform", "legacy_local" ]
    elsif normalized.start_with?(LEGACY_PRODUCT_SKU_PREFIX)
      [ "freeform", "legacy_product_sku" ]
    else
      digits = normalized.gsub(/[^0-9X]/, "")
      if digits.length == 13 && digits.start_with?("201") && digits.match?(/\A[0-9]+\z/)
        [ "house", nil ]
      elsif [ 8, 12, 13, 14 ].include?(digits.length) && digits.match?(/\A[0-9]+\z/)
        [ "gtin", nil ]
      elsif digits.length == 10 && digits.match?(/\A[0-9]{9}[0-9X]\z/)
        [ "isbn", nil ]
      else
        [ "freeform", "import_reference" ]
      end
    end
  end
  private_class_method :classify_product_sku

  def self.normalize_sku_for_family(sku, family, scope)
    case family
    when "gtin", "house" then normalize_standard_digits(sku)
    when "isbn" then sku.gsub(/[^0-9X]/, "").upcase
    when "freeform" then normalize_freeform(sku, scope)
    else
      sku
    end
  end
  private_class_method :normalize_sku_for_family

  def self.identifier_accepts_sku?(identifier, classified_family)
    case identifier.validation_family
    when "gtin"
      classified_family == "gtin"
    when "house"
      classified_family == "house"
    when "freeform"
      classified_family == "freeform"
    when "isbn"
      classified_family == "isbn"
    else
      false
    end
  end
  private_class_method :identifier_accepts_sku?

  def self.infer_freeform_scope(value)
    normalized = value.to_s.strip.upcase
    return "legacy_local" if normalized.start_with?(LEGACY_LOCAL_PREFIX)
    return "legacy_product_sku" if normalized.start_with?(LEGACY_PRODUCT_SKU_PREFIX)

    "import_reference"
  end

  def self.normalize_preview(identifier_type, value)
    preview = validation_preview_for_legacy_type(identifier_type: identifier_type, value: value)
    normalized = preview[:normalized]
    raise IdentifierError, preview[:message].presence || "Invalid identifier" if normalized.blank? || normalized == "—"

    normalized
  end

  def self.legacy_type_to_family(identifier_type)
    case identifier_type.to_s
    when "isbn10" then "isbn"
    when "isbn13", "ean", "upc", "gtin" then "gtin"
    else "freeform"
    end
  end

  def self.freeform_scope_for_legacy_type(identifier_type, value = nil)
    case identifier_type.to_s
    when "publisher_number" then "publisher_number"
    when "local" then "legacy_local"
    else infer_freeform_scope(value.to_s)
    end
  end

  def self.validation_preview_for_legacy_type(identifier_type:, value:)
    family = legacy_type_to_family(identifier_type)
    freeform_scope = family == "freeform" ? freeform_scope_for_legacy_type(identifier_type, value) : nil
    validation_preview(validation_family: family, value: value, freeform_scope: freeform_scope)
  end

  def self.add_identifier_for_legacy_type!(product:, identifier_type:, value:, primary: false, actor: nil, source: "manual")
    family = legacy_type_to_family(identifier_type)
    freeform_scope = family == "freeform" ? freeform_scope_for_legacy_type(identifier_type, value) : nil
    add_identifier!(
      product: product,
      validation_family: family,
      value: value,
      freeform_scope: freeform_scope,
      primary: primary,
      actor: actor,
      source: source
    )
  end

  def self.add_gtin!(product:, value:, primary:, actor:, source:)
    normalized = normalize_standard_digits(value)
    ensure_unique_gtin!(product:, normalized:)
    validation = validate_gtin_family(normalized)

    identifier = product.product_identifiers.create!(
      validation_family: "gtin",
      identifier_value: normalized,
      normalized_identifier: normalized,
      primary_identifier: false,
      valid_check_digit: validation[:valid_check_digit],
      validation_message: validation[:validation_message],
      source: source,
      active: true
    )

    maybe_create_isbn10_alternate!(product:, gtin_normalized: normalized, actor:, source:) if validation[:valid_check_digit]
    set_primary!(identifier:, actor: actor, source: source) if primary || product.primary_identifier.blank?

    record_audit!(
      actor: actor,
      event_name: "product_identifier.created",
      identifier: identifier,
      source: source
    )
    identifier
  end
  private_class_method :add_gtin!

  def self.add_freeform!(product:, value:, freeform_scope:, primary:, actor:, source:)
    scope = freeform_scope.presence || infer_freeform_scope(value)
    normalized = normalize_freeform(value, scope)
    ensure_unique_freeform!(product:, normalized:, freeform_scope: scope)

    identifier = product.product_identifiers.create!(
      validation_family: "freeform",
      identifier_value: preserve_freeform_display(value, normalized, scope),
      normalized_identifier: normalized,
      freeform_scope: scope,
      primary_identifier: false,
      valid_check_digit: nil,
      validation_message: nil,
      source: source,
      active: true
    )

    set_primary!(identifier:, actor: actor, source: source) if primary || product.primary_identifier.blank?

    record_audit!(
      actor: actor,
      event_name: "product_identifier.created",
      identifier: identifier,
      source: source
    )
    identifier
  end
  private_class_method :add_freeform!

  def self.add_isbn10!(product:, value:, actor:, source:)
    normalized = normalize_standard_digits(value)
    ensure_unique_isbn!(product:, normalized:)
    isbn13_normalized = convert_isbn10_to_isbn13(normalized)
    ensure_unique_gtin!(product:, normalized: isbn13_normalized)
    validation = validate_isbn10(normalized)

    isbn = product.product_identifiers.create!(
      validation_family: "isbn",
      identifier_value: preserve_isbn10_display(value, normalized),
      normalized_identifier: normalized,
      primary_identifier: false,
      valid_check_digit: validation[:valid_check_digit],
      validation_message: validation[:validation_message],
      source: source,
      active: true
    )

    if validation[:valid_check_digit]
      gtin_validation = validate_gtin_family(isbn13_normalized)
      gtin = product.product_identifiers.find_or_initialize_by(
        validation_family: "gtin",
        normalized_identifier: isbn13_normalized
      )
      gtin.assign_attributes(
        identifier_value: isbn13_normalized,
        primary_identifier: false,
        valid_check_digit: gtin_validation[:valid_check_digit],
        validation_message: gtin_validation[:validation_message],
        source: "isbn_alternate_created",
        active: true
      )
      gtin.save!

      set_primary!(identifier: gtin, actor: actor, source: source)

      record_audit!(
        actor: actor,
        event_name: "product_identifier.isbn_alternate_created",
        identifier: gtin,
        source: source,
        details: {
          "isbn10" => normalized,
          "isbn13" => isbn13_normalized
        }
      )
    elsif product.primary_identifier.blank?
      set_primary!(identifier: isbn, actor: actor, source: source)
    end
    record_audit!(
      actor: actor,
      event_name: "product_identifier.created",
      identifier: isbn,
      source: source
    )
    isbn
  end
  private_class_method :add_isbn10!

  def self.maybe_create_isbn10_alternate!(product:, gtin_normalized:, actor:, source:)
    return unless gtin_normalized.match?(/\A978[0-9]{10}\z/)

    isbn10 = convert_isbn13_to_isbn10(gtin_normalized)
    return if isbn10.blank?
    return if product.product_identifiers.active_records.exists?(validation_family: "isbn", normalized_identifier: isbn10)

    ensure_unique_isbn!(product:, normalized: isbn10)
    validation = validate_isbn10(isbn10)
    return unless validation[:valid_check_digit]
    alternate = product.product_identifiers.create!(
      validation_family: "isbn",
      identifier_value: isbn10,
      normalized_identifier: isbn10,
      primary_identifier: false,
      valid_check_digit: validation[:valid_check_digit],
      validation_message: validation[:validation_message],
      source: "isbn_alternate_created",
      active: true
    )

    record_audit!(
      actor: actor,
      event_name: "product_identifier.isbn_alternate_created",
      identifier: alternate,
      source: source,
      details: {
        "isbn10" => isbn10,
        "isbn13" => gtin_normalized
      }
    )
  end
  private_class_method :maybe_create_isbn10_alternate!

  def self.update_house!(identifier:, value:, actor:, source:)
    normalized = normalize_standard_digits(value)
    validation = validate_house_value!(normalized)
    ensure_unique_gtin!(product: identifier.product, normalized:, excluding_identifier_id: identifier.id)

    identifier.update!(
      identifier_value: normalized,
      normalized_identifier: normalized,
      valid_check_digit: validation[:valid_check_digit],
      validation_message: validation[:validation_message],
      active: true
    )
    sync_product_sku_cache!(identifier.product) if identifier.primary_identifier?

    record_audit!(
      actor: actor,
      event_name: "product_identifier.updated",
      identifier: identifier,
      source: source
    )
    identifier
  end
  private_class_method :update_house!

  def self.update_gtin_like!(identifier:, value:, actor:, source:)
    normalized = normalize_standard_digits(value)
    ensure_unique_gtin!(product: identifier.product, normalized:, excluding_identifier_id: identifier.id)
    validation = validate_gtin_family(normalized)

    identifier.update!(
      identifier_value: normalized,
      normalized_identifier: normalized,
      valid_check_digit: validation[:valid_check_digit],
      validation_message: validation[:validation_message],
      active: true
    )
    sync_product_sku_cache!(identifier.product) if identifier.primary_identifier?

    record_audit!(
      actor: actor,
      event_name: "product_identifier.updated",
      identifier: identifier,
      source: source
    )
    identifier
  end
  private_class_method :update_gtin_like!

  def self.update_freeform!(identifier:, value:, actor:, source:)
    scope = identifier.freeform_scope
    normalized = normalize_freeform(value, scope)
    ensure_unique_freeform!(
      product: identifier.product,
      normalized:,
      freeform_scope: scope,
      excluding_identifier_id: identifier.id
    )

    identifier.update!(
      identifier_value: preserve_freeform_display(value, normalized, scope),
      normalized_identifier: normalized,
      active: true
    )
    sync_product_sku_cache!(identifier.product) if identifier.primary_identifier?

    record_audit!(
      actor: actor,
      event_name: "product_identifier.updated",
      identifier: identifier,
      source: source
    )
    identifier
  end
  private_class_method :update_freeform!

  def self.ensure_unique_gtin!(product:, normalized:, excluding_identifier_id: nil)
    conflicting = find_conflicting_gtin(product:, normalized:, excluding_identifier_id:)
    return if conflicting.blank?

    raise IdentifierError, conflict_message(conflicting)
  end
  private_class_method :ensure_unique_gtin!

  def self.ensure_unique_isbn!(product:, normalized:, excluding_identifier_id: nil)
    conflicting = find_conflicting_isbn(product:, normalized:, excluding_identifier_id:)
    return if conflicting.blank?

    raise IdentifierError, conflict_message(conflicting)
  end
  private_class_method :ensure_unique_isbn!

  def self.ensure_unique_freeform!(product:, normalized:, freeform_scope:, excluding_identifier_id: nil)
    scope = ProductIdentifier.active_records.where(
      product_id: product.id,
      validation_family: "freeform",
      freeform_scope: freeform_scope,
      normalized_identifier: normalized
    )
    scope = scope.where.not(id: excluding_identifier_id) if excluding_identifier_id.present?
    return if scope.none?

    raise IdentifierError, "Identifier #{normalized} is already assigned to this product."
  end
  private_class_method :ensure_unique_freeform!

  def self.find_conflicting_gtin(product:, normalized:, excluding_identifier_id: nil)
    scope = ProductIdentifier.active_records
      .where(validation_family: %w[gtin house], normalized_identifier: normalized)
      .where.not(product_id: product.id)
    scope = scope.where.not(id: excluding_identifier_id) if excluding_identifier_id.present?
    scope.includes(:product).first
  end
  private_class_method :find_conflicting_gtin

  def self.find_conflicting_isbn(product:, normalized:, excluding_identifier_id: nil)
    scope = ProductIdentifier.active_records
      .where(validation_family: "isbn", normalized_identifier: normalized)
      .where.not(product_id: product.id)
    scope = scope.where.not(id: excluding_identifier_id) if excluding_identifier_id.present?
    scope.includes(:product).first
  end
  private_class_method :find_conflicting_isbn

  def self.conflict_message(conflicting)
    product_name = conflicting.product.name
    "Identifier #{conflicting.normalized_identifier} is already assigned to \"#{product_name}\"."
  end
  private_class_method :conflict_message

  def self.normalize_freeform(value, freeform_scope)
    case freeform_scope
    when "publisher_number"
      normalize_publisher_number(value)
    else
      value.to_s.strip.upcase
    end
  end
  private_class_method :normalize_freeform

  def self.preserve_freeform_display(value, normalized, freeform_scope)
    case freeform_scope
    when "publisher_number" then value.to_s.strip
    else normalized
    end
  end
  private_class_method :preserve_freeform_display

  def self.preserve_isbn10_display(value, normalized)
    cleaned = value.to_s.strip.upcase
    cleaned.match?(/\A[0-9]{9}[0-9X]\z/) ? cleaned : normalized
  end
  private_class_method :preserve_isbn10_display

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

  def self.validate_house_segment!(normalized)
    raise IdentifierError, "House identifiers must use segment 201" unless normalized.match?(/\A201[0-9]{10}\z/)
  end
  private_class_method :validate_house_segment!

  def self.validate_house_value!(normalized)
    validate_house_segment!(normalized)
    validation = validate_gtin_family(normalized)
    unless validation[:valid_check_digit]
      raise IdentifierError, validation[:validation_message].presence || "House identifier check digit is invalid"
    end

    validation
  end
  private_class_method :validate_house_value!

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

  def self.convert_isbn13_to_isbn10(isbn13)
    return if isbn13.blank? || !isbn13.start_with?("978")

    core = isbn13[3, 9]
    sum = 0
    core.chars.each_with_index do |char, index|
      sum += (10 - index) * char.to_i
    end
    check = (11 - (sum % 11)) % 11
    check_char = check == 10 ? "X" : check.to_s
    "#{core}#{check_char}"
  end
  private_class_method :convert_isbn13_to_isbn10

  def self.valid_result
    { valid_check_digit: true, validation_message: nil }
  end
  private_class_method :valid_result

  def self.invalid_result(message)
    { valid_check_digit: false, validation_message: message }
  end
  private_class_method :invalid_result

  def self.identifier_payload(identifier)
    {
      "product_id" => identifier.product_id,
      "identifier_id" => identifier.id,
      "validation_family" => identifier.validation_family,
      "normalized_identifier" => identifier.normalized_identifier,
      "freeform_scope" => identifier.freeform_scope,
      "primary_identifier" => identifier.primary_identifier
    }
  end
  private_class_method :identifier_payload

  def self.record_audit!(actor:, event_name:, identifier:, source:, details: {})
    return if actor.blank?

    AuditEvents.record!(
      actor: actor,
      event_name: event_name,
      auditable: identifier,
      details: identifier_payload(identifier).merge("source" => source).merge(details.stringify_keys)
    )
  end
  private_class_method :record_audit!
end
