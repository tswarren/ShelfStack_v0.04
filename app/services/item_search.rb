# frozen_string_literal: true

class ItemSearch
  Result = Struct.new(:presenter, :match_type, keyword_init: true)

  def self.call(query:, limit: 50)
    return [] if query.to_s.strip.blank?

    Items::IndexQuery.call(query: query, per_page: limit, page: 1).results
  end
end
