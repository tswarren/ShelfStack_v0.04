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

    def self.checklist(customer:)
      new(customer:).checklist
    end

    def initialize(customer:)
      @customer = customer
    end

    def validate!
      missing = check
      raise Error, missing.first if missing.any?
    end

    def check
      checklist.filter_map { |row| row[:message] unless row[:met] }
    end

    def checklist
      return [ { key: :customer, label: "Customer", met: false, message: "Customer is required." } ] if customer.blank?

      [
        checklist_row(:first_name, "First name", customer.first_name),
        checklist_row(:last_name, "Last name", customer.last_name),
        checklist_row(:address_line1, "Address line 1", customer.address_line1),
        checklist_row(:city, "City", customer.city),
        checklist_row(:region_code, "State / province", customer.region_code),
        checklist_row(:postal_code, "Postal code", customer.postal_code)
      ]
    end

    def checklist_row(key, label, value)
      met = value.present?
      {
        key: key,
        label: label,
        met: met,
        message: "Customer #{label.downcase} is required."
      }
    end

    private

    attr_reader :customer
  end
end
