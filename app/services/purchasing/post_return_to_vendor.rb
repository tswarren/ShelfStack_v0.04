# frozen_string_literal: true

module Purchasing
  class PostReturnToVendor
    class PostingError < StandardError; end

    def self.call(return_to_vendor:, posted_by_user:)
      new(return_to_vendor:, posted_by_user:).call
    end

    def initialize(return_to_vendor:, posted_by_user:)
      @return_to_vendor = return_to_vendor
      @posted_by_user = posted_by_user
    end

    def call
      return return_to_vendor.inventory_posting if return_to_vendor.posted?

      raise PostingError, "Return to vendor is not a draft" unless return_to_vendor.draft?
      raise PostingError, "Return to vendor has no lines" if return_to_vendor.return_to_vendor_lines.empty?

      return_to_vendor.return_to_vendor_lines.each do |line|
        raise PostingError, "Line #{line.line_number} has zero quantity" if line.quantity.zero?

        Inventory::Eligibility.ensure_eligible!(line.product_variant)

        if ReturnabilityResolver.resolve(variant: line.product_variant, vendor: return_to_vendor.vendor) == "non_returnable"
          raise PostingError, "Line #{line.line_number} is not returnable for this vendor"
        end
      end

      posting = nil
      ReturnToVendor.transaction do
        lines = return_to_vendor.return_to_vendor_lines.map do |line|
          unit_cost = moving_average_unit_cost_for(line)

          Inventory::Post::LinePayload.new(
            product_variant: line.product_variant,
            quantity_delta: -line.quantity,
            movement_type: "vendor_return",
            manual_unit_cost_cents: unit_cost,
            cost_source: unit_cost.present? ? "moving_average" : nil,
            inventory_location: nil,
            inventory_reason_code: nil
          )
        end

        posting = Inventory::Post.call(
          store: return_to_vendor.store,
          posted_by_user: posted_by_user,
          posting_type: "vendor_return",
          source: return_to_vendor,
          lines: lines,
          idempotency_key: "return_to_vendor:#{return_to_vendor.id}",
          notes: return_to_vendor.notes
        )

        return_to_vendor.update!(
          status: "posted",
          posted_at: posting.posted_at,
          posted_by_user: posted_by_user,
          inventory_posting: posting
        )

        AuditEvents.record!(
          actor: posted_by_user,
          event_name: "return_to_vendor.posted",
          auditable: return_to_vendor,
          details: { "inventory_posting_id" => posting.id }
        )
      end

      posting
    end

    private

    attr_reader :return_to_vendor, :posted_by_user

    def moving_average_unit_cost_for(line)
      balance = InventoryBalance.find_by(store: return_to_vendor.store, product_variant: line.product_variant)
      balance&.moving_average_unit_cost_cents || balance&.unit_cost_cents
    end
  end
end
