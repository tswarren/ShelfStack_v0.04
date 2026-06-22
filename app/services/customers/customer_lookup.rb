# frozen_string_literal: true

module Customers
  class CustomerLookup
    Result = Data.define(:status, :customers, :message)

    def self.call(query:, mode: :exact, active_only: true)
      new(query:, mode:, active_only:).call
    end

    def initialize(query:, mode: :exact, active_only: true)
      @query = query.to_s.strip
      @mode = mode.to_sym
      @active_only = active_only
    end

    def call
      return Result.new(status: :not_found, customers: [], message: "Enter a customer name, email, or phone.") if query.blank?

      if mode == :search
        return search_results if query.length >= 2

        return Result.new(status: :not_found, customers: [], message: "Type at least 2 characters to search.")
      end

      resolve_exact
    end

    private

    attr_reader :query, :mode, :active_only

    def resolve_exact
      matches = []
      matches.concat(find_by_email)
      matches.concat(find_by_phone)
      matches.concat(find_by_display_name(exact: true))
      matches = dedupe_customers(matches)

      build_result(matches, not_found_message: "No matching customer found.")
    end

    def search_results
      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
      matches = base_scope
        .where(
          "customers.display_name ILIKE :q OR customers.email ILIKE :q OR customers.phone ILIKE :q",
          q: pattern
        )
        .order(:display_name)
        .limit(15)
        .to_a

      if matches.empty?
        Result.new(status: :not_found, customers: [], message: "No customers matched your search.")
      else
        Result.new(status: :search, customers: matches, message: nil)
      end
    end

    def find_by_email
      return [] if query.exclude?("@")

      base_scope.where("LOWER(customers.email) = ?", query.downcase).to_a
    end

    def find_by_phone
      digits = query.gsub(/\D/, "")
      return [] if digits.length < 7

      base_scope.where("regexp_replace(customers.phone, '[^0-9]', '', 'g') = ?", digits).to_a
    end

    def find_by_display_name(exact:)
      if exact
        base_scope.where("LOWER(customers.display_name) = ?", query.downcase).to_a
      else
        []
      end
    end

    def build_result(customers, not_found_message:)
      if customers.empty?
        Result.new(status: :not_found, customers: [], message: not_found_message)
      elsif customers.size == 1
        Result.new(status: :found, customers: customers, message: nil)
      else
        Result.new(status: :ambiguous, customers: customers.sort_by(&:display_name), message: "Multiple customers matched. Choose one.")
      end
    end

    def dedupe_customers(customers)
      customers.uniq(&:id)
    end

    def base_scope
      active_only ? Customer.active_records : Customer.all
    end
  end
end
