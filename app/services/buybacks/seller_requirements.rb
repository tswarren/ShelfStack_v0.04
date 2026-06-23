# frozen_string_literal: true

module Buybacks
  class SellerRequirements
    class Error < StandardError; end

    def self.validate!(customer:)
      new(customer:).validate!
    end

    def initialize(customer:)
      @customer = customer
    end

    def validate!
      raise Error, "Customer is required." if customer.blank?
      raise Error, "Customer first name is required." if customer.first_name.blank?
      raise Error, "Customer last name is required." if customer.last_name.blank?
      raise Error, "Customer address is required." if customer.address_line1.blank?
      raise Error, "Customer city is required." if customer.city.blank?
      raise Error, "Customer state/province is required." if customer.region_code.blank?
      raise Error, "Customer postal code is required." if customer.postal_code.blank?
    end

    private

    attr_reader :customer
  end
end
