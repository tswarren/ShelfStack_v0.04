# frozen_string_literal: true

module DemandLines
  class EligibilityResolver
    Result = Data.define(:allowed, :blocking_reasons)

    BlockingReason = Data.define(:code, :message)

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(capture_intent:, variant: nil, customer: nil, customer_name_snapshot: nil,
                   source: nil, purpose: nil)
      @capture_intent = capture_intent.to_s
      @variant = variant
      @customer = customer
      @customer_name_snapshot = customer_name_snapshot.to_s.strip
      @source = source
      @purpose = purpose
    end

    def call
      reasons = []
      entry = IntentMapping.fetch(capture_intent)
      if entry.blank?
        reasons << reason(:invalid_intent, "Invalid capture intent")
        return Result.new(allowed: false, blocking_reasons: reasons)
      end

      if source.present? && purpose.present? && !IntentMapping.valid_triple?(capture_intent:, source:, purpose:)
        reasons << reason(:invalid_combination, "Source and purpose do not match capture intent")
      end

      if entry.variant_required && variant.blank?
        reasons << reason(:variant_required, "Variant is required")
      end

      if variant.present?
        policy = ProductVariants::OperationalPolicy.for(variant)
        unless variant.active?
          reasons << reason(:inactive_variant, "Variant is inactive")
        end
        if entry.vendor_orderable_required && !policy.vendor_orderable?
          reasons << reason(:not_vendor_orderable, "Variant is not vendor-orderable")
        end
        if !entry.used_like_allowed && policy.used_like?
          reasons << reason(:used_like_not_allowed, "Used-like variants are not allowed for this demand type")
        end
        if capture_intent == "used_wanted" && !policy.used_like?
          reasons << reason(:used_wanted_requires_used, "Used wanted demand requires a used-like variant")
        end
        block = policy.customer_request_block_reason(request_type: legacy_request_type)
        if block.present?
          reasons << reason(:policy_block, block)
        end
      end

      case entry.customer_required
      when IntentMapping::CUSTOMER_RECORD
        if customer.blank?
          reasons << reason(:customer_required, "Customer record is required")
        end
      when IntentMapping::CUSTOMER_OR_SNAPSHOT
        if customer.blank? && customer_name_snapshot.blank?
          reasons << reason(:customer_or_snapshot_required, "Customer or walk-in name is required")
        end
      end

      Result.new(allowed: reasons.empty?, blocking_reasons: reasons)
    end

    def blocking?
      !call.allowed
    end

    def blocking_message
      call.blocking_reasons.map(&:message).join("; ")
    end

    private

    attr_reader :capture_intent, :variant, :customer, :customer_name_snapshot, :source, :purpose

    def reason(code, message)
      BlockingReason.new(code: code, message: message)
    end

    def legacy_request_type
      case capture_intent
      when "special_order" then "special_order"
      when "hold", "notify", "used_wanted", "research" then capture_intent
      else "research"
      end
    end
  end
end
