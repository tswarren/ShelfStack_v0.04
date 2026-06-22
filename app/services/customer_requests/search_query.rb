# frozen_string_literal: true

module CustomerRequests
  class SearchQuery
    MIN_QUERY_LENGTH = 2

    def self.apply(relation, query)
      new(relation, query).apply
    end

    def initialize(relation, query)
      @relation = relation
      @query = query.to_s.strip
    end

    def apply
      return @relation if @query.blank?
      return @relation if @query.length < MIN_QUERY_LENGTH

      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"

      @relation.left_joins(:customer, customer_request_lines: :product_variant)
               .where(
                 <<~SQL.squish,
                   customer_requests.request_number ILIKE :q
                   OR customer_requests.customer_name_snapshot ILIKE :q
                   OR customer_requests.customer_email_snapshot ILIKE :q
                   OR customer_requests.customer_phone_snapshot ILIKE :q
                   OR customers.display_name ILIKE :q
                   OR customers.email ILIKE :q
                   OR customers.phone ILIKE :q
                   OR customer_request_lines.provisional_title ILIKE :q
                   OR customer_request_lines.provisional_identifier ILIKE :q
                   OR product_variants.sku ILIKE :q
                 SQL
                 q: pattern
               )
               .distinct
    end
  end
end
