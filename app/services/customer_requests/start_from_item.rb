# frozen_string_literal: true

module CustomerRequests
  class StartFromItem
    class StartError < StandardError; end

    Result = Data.define(:request, :line, :reservation, :special_order)

    REQUEST_TYPES = %w[hold special_order notify].freeze

    def self.call!(store:, variant:, actor:, request_type:, quantity: 1, customer: nil,
                   customer_name_snapshot: nil, customer_email_snapshot: nil, customer_phone_snapshot: nil,
                   preferred_contact_method: nil, needed_by_date: nil, notes: nil, expires_at: nil,
                   override_authorized_by_user: nil, override_reason: nil)
      new(
        store:, variant:, actor:, request_type:, quantity:, customer:,
        customer_name_snapshot:, customer_email_snapshot:, customer_phone_snapshot:,
        preferred_contact_method:, needed_by_date:, notes:, expires_at:,
        override_authorized_by_user:, override_reason:
      ).call!
    end

    def initialize(store:, variant:, actor:, request_type:, quantity: 1, customer: nil,
                   customer_name_snapshot: nil, customer_email_snapshot: nil, customer_phone_snapshot: nil,
                   preferred_contact_method: nil, needed_by_date: nil, notes: nil, expires_at: nil,
                   override_authorized_by_user: nil, override_reason: nil)
      @store = store
      @variant = variant
      @actor = actor
      @request_type = request_type.to_s
      @quantity = quantity.to_i
      @customer = customer
      @customer_name_snapshot = customer_name_snapshot
      @customer_email_snapshot = customer_email_snapshot
      @customer_phone_snapshot = customer_phone_snapshot
      @preferred_contact_method = preferred_contact_method
      @needed_by_date = needed_by_date
      @notes = notes
      @expires_at = expires_at
      @override_authorized_by_user = override_authorized_by_user
      @override_reason = override_reason
    end

    def call!
      validate_inputs!

      request = nil
      line = nil
      reservation = nil
      special_order = nil

      CustomerRequest.transaction do
        request = CustomerRequests::Create.call(
          store: store,
          created_by_user: actor,
          attributes: request_attributes,
          lines: [ line_attributes ]
        )
        line = request.customer_request_lines.first!

        case request_type
        when "hold"
          reservation = create_hold!(request:, line:)
        when "special_order"
          special_order = create_special_order!(line:)
        when "notify"
          request.refresh_status_from_lines!
        end
      end

      Result.new(request:, line:, reservation:, special_order:)
    end

    private

    attr_reader :store, :variant, :actor, :request_type, :quantity, :customer,
                :customer_name_snapshot, :customer_email_snapshot, :customer_phone_snapshot,
                :preferred_contact_method, :needed_by_date, :notes, :expires_at,
                :override_authorized_by_user, :override_reason

    def validate_inputs!
      raise StartError, "Store is required" if store.blank?
      raise StartError, "Variant is required" if variant.blank?
      raise StartError, "Invalid request type" unless REQUEST_TYPES.include?(request_type)
      raise StartError, "Quantity must be positive" unless quantity.positive?
      raise StartError, "Variant must be active" unless variant.active?
      raise StartError, "Customer or walk-in name is required" if customer.blank? && customer_name_snapshot.blank?
      raise StartError, "Customer record is required for special orders" if request_type == "special_order" && customer.blank?
    end

    def request_attributes
      {
        customer: customer,
        customer_name_snapshot: customer&.display_name || customer_name_snapshot,
        customer_email_snapshot: customer&.email || customer_email_snapshot,
        customer_phone_snapshot: customer&.phone || customer_phone_snapshot,
        preferred_contact_method: preferred_contact_method,
        needed_by_date: needed_by_date,
        notes: notes,
        source: "in_store"
      }
    end

    def line_attributes
      {
        request_type: request_type,
        requested_quantity: quantity,
        status: "matched",
        product_variant_id: variant.id,
        product_id: variant.product_id
      }
    end

    def create_hold!(request:, line:)
      CustomerRequests::CreateHoldFromLine.call!(
        request: request,
        line: line,
        store: store,
        actor: actor,
        quantity: quantity,
        expires_at: expires_at,
        override_authorized_by_user: override_authorized_by_user,
        override_reason: override_reason
      )
    end

    def create_special_order!(line:)
      special_order = SpecialOrders::CreateFromRequestLine.call!(line: line, created_by_user: actor, quantity: quantity)
      SpecialOrders::Approve.call!(special_order: special_order, approved_by_user: actor)
      special_order
    end
  end
end
