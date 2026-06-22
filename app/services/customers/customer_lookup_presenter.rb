# frozen_string_literal: true

module Customers
  class CustomerLookupPresenter
    def self.as_json(result)
      new(result).as_json
    end

    def initialize(result)
      @result = result
    end

    def as_json
      {
        status: result.status.to_s,
        message: result.message,
        customers: result.customers.map { |customer| customer_json(customer) }
      }
    end

    private

    attr_reader :result

    def customer_json(customer)
      {
        id: customer.id,
        display_name: customer.display_name,
        email: customer.email,
        phone: customer.phone,
        preferred_contact_method: customer.preferred_contact_method
      }
    end
  end
end
