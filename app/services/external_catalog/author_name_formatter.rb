# frozen_string_literal: true

module ExternalCatalog
  class AuthorNameFormatter
    ROLE_SUFFIX = /\[[^\]]+\]\s*\z/.freeze
    COLLECTIVE_PREFIX = /\AThe\s+/i.freeze

    def self.format(name, default_role: "author")
      new(default_role:).format(name)
    end

    def initialize(default_role: "author")
      @default_role = default_role.to_s.strip
    end

    def format(name)
      value = name.to_s.strip
      return value if value.blank?
      return value if value.match?(ROLE_SUFFIX)

      display_name = value
      formatted_name = if display_name.include?(",")
                         display_name
      elsif single_token?(display_name) || collective?(display_name)
                         display_name
      else
                         invert_personal_name(display_name)
      end

      return formatted_name if single_token?(display_name) || collective?(display_name)

      append_role(formatted_name)
    end

    private

    def single_token?(display_name)
      display_name.split(/\s+/).one?
    end

    def collective?(display_name)
      display_name.match?(COLLECTIVE_PREFIX)
    end

    def invert_personal_name(display_name)
      parts = display_name.split(/\s+/)
      return display_name if parts.length < 2

      family_name = parts.last
      given_names = parts[0..-2].join(" ")
      "#{family_name}, #{given_names}"
    end

    def append_role(display_name)
      return display_name if @default_role.blank?

      "#{display_name} [#{@default_role}]"
    end
  end
end
