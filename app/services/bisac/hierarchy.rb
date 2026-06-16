# frozen_string_literal: true

module Bisac
  module Hierarchy
    module_function

    def parent_code(code)
      normalized = normalize_code(code)
      return nil if normalized.blank?

      suffix = normalized[3..]
      return nil if suffix == "000000"
      return normalized[0, 6] + "000" if suffix[3..] != "000"

      normalized[0, 3] + "000000"
    end

    def depth(code)
      depth = 0
      current = normalize_code(code)
      while (parent = parent_code(current))
        depth += 1
        current = parent
      end
      depth
    end

    def sort_order(code)
      normalize_code(code)[3..].to_i
    end

    def synthetic_heading(parent_code, child_heading:)
      segments = child_heading.to_s.split(" / ").map(&:strip).reject(&:blank?)
      return parent_code if segments.empty?

      parent_depth = depth(parent_code)
      if segments.size > parent_depth + 1
        return child_heading.to_s.strip
      end

      prefix_segments = segments[0...-1]
      return segments.first if prefix_segments.empty?

      (prefix_segments + [ "General" ]).join(" / ")
    end

    def normalize_code(code)
      code.to_s.strip.upcase
    end
  end
end
