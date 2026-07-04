# frozen_string_literal: true

module Sourcing
  class VendorCardPresenter
    include Rails.application.routes.url_helpers

    def initialize(candidate:, sourcing_run:, store:, run_unresolved:)
      @candidate = candidate
      @sourcing_run = sourcing_run
      @store = store
      @run_unresolved = run_unresolved
    end

    attr_reader :candidate, :sourcing_run, :store, :run_unresolved

    delegate :vendor, :source_level, :warnings, to: :candidate

    def capability
      @capability ||= Vendors::CapabilityResolver.call(
        vendor: vendor,
        product: sourcing_run.product,
        product_variant: sourcing_run.product_variant
      )
    end

    def fulfillment_methods_label
      capability.fulfillment_methods_supported.map(&:humanize).join(", ").presence || "—"
    end

    def discount_hint
      suggestion = candidate.suggestion
      bps = if suggestion.product_variant_vendor.present?
        suggestion.product_variant_vendor.supplier_discount_bps
      elsif suggestion.product_vendor.present?
        suggestion.product_vendor.supplier_discount_bps
      else
        vendor.default_supplier_discount_bps
      end

      bps.present? ? ApplicationController.helpers.format_basis_points(bps) : "—"
    end

    def source_record_hint
      case candidate.suggestion.source
      when "product_variant_vendor" then "Variant vendor source"
      when "product_vendor" then "Product vendor source"
      when "preferred_vendor" then "Preferred vendor"
      else source_level.to_s.humanize
      end
    end

    def draft_purchase_orders
      @draft_purchase_orders ||= PurchaseOrder.drafts
                                              .where(store: store, vendor: vendor)
                                              .includes(:purchase_order_lines)
                                              .order(updated_at: :desc)
    end

    def draft_po_label(po)
      "PO ##{po.id} · #{vendor.name} · #{po.purchase_order_lines.size} lines"
    end
  end
end
