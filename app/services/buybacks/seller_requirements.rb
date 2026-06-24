# frozen_string_literal: true

module Buybacks
  class SellerRequirements
    class Error < StandardError; end

    def self.validate!(customer:)
      new(customer:).validate!
    end

    def self.check(customer:)
      new(customer:).check
    end

    def initialize(customer:)
      @customer = customer
    end

    def validate!
      missing = check
      raise Error, missing.first if missing.any?
    end

    def check
      [].tap do |messages|
        messages << "Customer is required." if customer.blank?
        next if customer.blank?

        messages << "Customer first name is required." if customer.first_name.blank?
        messages << "Customer last name is required." if customer.last_name.blank?
        messages << "Customer address is required." if customer.address_line1.blank?
        messages << "Customer city is required." if customer.city.blank?
        messages << "Customer state/province is required." if customer.region_code.blank?
        messages << "Customer postal code is required." if customer.postal_code.blank?
      end
    end

    private

    attr_reader :customer
  end
end
