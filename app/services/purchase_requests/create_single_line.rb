# frozen_string_literal: true

module PurchaseRequests
  class CreateSingleLine
    class CreateError < StandardError; end

    def self.call!(store:, product_variant:, created_by_user:, requested_quantity: 1, request_reason: nil, notes: nil)
      new(
        store:,
        product_variant:,
        created_by_user:,
        requested_quantity:,
        request_reason:,
        notes:
      ).call!
    end

    def initialize(store:, product_variant:, created_by_user:, requested_quantity: 1, request_reason: nil, notes: nil)
      @store = store
      @product_variant = product_variant
      @created_by_user = created_by_user
      @requested_quantity = requested_quantity
      @request_reason = request_reason
      @notes = notes
    end

    def call!
      raise CreateError, "Variant is required" if product_variant.blank?
      raise CreateError, "Quantity must be positive" unless requested_quantity.to_i.positive?

      eligibility = Purchasing::OrderEligibilityResolver.call(
        product_variant: product_variant,
        context: :tbo
      )
      if eligibility.blocking?
        raise CreateError, eligibility.blocking_reasons.map(&:message).join("; ")
      end

      purchase_request = nil
      PurchaseRequest.transaction do
        purchase_request = PurchaseRequest.create!(
          store: store,
          status: "open",
          notes: notes
        )
        purchase_request.purchase_request_lines.create!(
          line_number: 1,
          product_variant: product_variant,
          requested_quantity: requested_quantity,
          request_reason: request_reason,
          status: "open"
        )

        AuditEvents.record!(
          actor: created_by_user,
          event_name: "purchase_request.created",
          auditable: purchase_request,
          details: { "product_variant_id" => product_variant.id, "single_line" => true, "store_id" => store.id }
        )
      end

      purchase_request
    end

    private

    attr_reader :store, :product_variant, :created_by_user, :requested_quantity, :request_reason, :notes
  end
end
