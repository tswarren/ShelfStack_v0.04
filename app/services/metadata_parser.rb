# frozen_string_literal: true

class MetadataParser
  SUBJECT_SCHEME = /\[(?<scheme>[A-Za-z0-9_]+)(?:\/(?<code>[^\]]+))?\]\s*\z/.freeze

  def self.parse_creators(input)
    return [] if input.blank?

    split_outside_brackets(input).filter_map do |entry|
      entry = entry.strip
      next if entry.blank?

      parse_creator_entry(entry)
    end
  end

  def self.parse_subjects(input)
    return [] if input.blank?

    split_outside_brackets(input).filter_map do |entry|
      entry = entry.strip
      next if entry.blank?

      parse_subject_entry(entry)
    end
  end

  def self.split_outside_brackets(input)
    parts = []
    current = +""
    depth = 0

    input.each_char do |char|
      if char == "["
        depth += 1
        current << char
      elsif char == "]"
        depth -= 1 if depth.positive?
        current << char
      elsif char == ";" && depth.zero?
        parts << current
        current = +""
      else
        current << char
      end
    end

    parts << current unless current.empty?
    parts
  end
  private_class_method :split_outside_brackets

  def self.parse_creator_entry(entry)
    display_name = entry
    roles = []

    if entry.match?(/\[[^\]]+\]\s*\z/)
      display_name = entry.sub(/\[[^\]]+\]\s*\z/, "").strip
      roles = entry[/\[([^\]]+)\]\s*\z/, 1].split(";").map { |role| normalize_token(role) }.reject(&:blank?)
    end

    result = {
      "display_name" => display_name,
      "name_type" => "unknown",
      "family_name" => nil,
      "given_names" => nil,
      "roles" => roles
    }

    if display_name.include?(",")
      family_name, given_names = display_name.split(",", 2).map(&:strip)
      result["name_type"] = "person"
      result["family_name"] = family_name
      result["given_names"] = given_names
    end

    result
  end
  private_class_method :parse_creator_entry

  def self.parse_subject_entry(entry)
    heading = entry
    scheme = "local"
    code = nil

    if entry.match?(SUBJECT_SCHEME)
      match = entry.match(SUBJECT_SCHEME)
      heading = entry.sub(SUBJECT_SCHEME, "").strip
      scheme = normalize_token(match[:scheme])
      code = match[:code]&.strip.presence
    end

    {
      "heading" => heading,
      "scheme" => scheme,
      "code" => code
    }
  end
  private_class_method :parse_subject_entry

  def self.normalize_token(value)
    value.to_s.strip.downcase.tr(" ", "_")
  end
  private_class_method :normalize_token
end
