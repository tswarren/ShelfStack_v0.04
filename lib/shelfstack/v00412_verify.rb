# frozen_string_literal: true

module Shelfstack
  module V00412Verify
    module_function

    SLICE_ORDER = %w[slice_0 slice_b slice_a slice_c slice_d slice_e slice_f slice_g final].freeze

    SPEC_BUNDLE = "docs/v0.04/v0.04-12-demand-ordering-ux".freeze

    def slice
      ENV.fetch("V00412_SLICE", "slice_0").downcase
    end

    def slice_index
      SLICE_ORDER.index(slice) || 0
    end

    def at_least?(target_slice)
      SLICE_ORDER.index(target_slice).to_i <= slice_index
    end

    def spec_bundle_exists?
      %w[spec.md data-model.md test-plan.md].all? do |file|
        File.exist?(Rails.root.join(SPEC_BUNDLE, file))
      end
    end

    def completion_stub_exists?
      File.exist?(Rails.root.join("docs/implementation/v0.04-12-completion.md"))
    end

    def workflow_presenter_exists?
      File.exist?(Rails.root.join("app/presenters/demand/demand_line_workflow_presenter.rb"))
    end

    def next_action_partial_exists?
      File.exist?(Rails.root.join("app/views/demand/demand_lines/_next_action_panel.html.erb"))
    end

    def capture_form_has_lookup?
      content = File.read(Rails.root.join("app/views/demand/demand_lines/new.html.erb"))
      content.include?("inventory-variant-lookup") && content.include?("customer-lookup")
    end

    def allocation_workbench_exists?
      File.exist?(Rails.root.join("app/views/demand/demand_lines/_allocation_workbench.html.erb")) &&
        File.exist?(Rails.root.join("app/services/demand_allocations/eligible_inbound_lines.rb"))
    end

    def sourcing_vendor_cards_exist?
      File.exist?(Rails.root.join("app/views/sourcing/runs/_suggested_vendor_cards.html.erb"))
    end

    def demand_to_po_services_exist?
      defined?(Purchasing::BuildPurchaseOrderFromDemand) &&
        defined?(Purchasing::DemandCoveragePlanner) &&
        defined?(Purchasing::AddDemandToPurchaseOrder)
    end

    def demand_to_po_routes_exist?
      routes = Rails.application.routes.url_helpers
      routes.respond_to?(:create_po_demand_demand_line_path) &&
        routes.respond_to?(:submit_create_po_demand_demand_line_path)
    end

    def receipt_pickup_visibility_exists?
      content = File.read(Rails.root.join("app/presenters/orders/receipt_show_presenter.rb"))
      content.include?("post_confirmation_message")
    end

    def pos_pickup_paths_exist?
      defined?(Pos::DemandPickupLookup) &&
        defined?(Pos::AddDemandAllocationLine) &&
        File.exist?(Rails.root.join("app/views/pos/transactions/_pickup_panel.html.erb"))
    end

    def no_legacy_ordering_reintroduced?
      Shelfstack::V00410Verify.legacy_tables_absent? &&
        Shelfstack::V00410Verify.legacy_models_absent?
    end

    def run!
      checks = []
      checks << check("spec_bundle_exists", spec_bundle_exists?) if at_least?("slice_0")
      checks << check("completion_stub_exists", completion_stub_exists?) if at_least?("slice_0")
      checks << check("workflow_presenter_exists", workflow_presenter_exists?) if at_least?("slice_b")
      checks << check("next_action_partial_exists", next_action_partial_exists?) if at_least?("slice_b")
      checks << check("capture_form_has_lookup", capture_form_has_lookup?) if at_least?("slice_a")
      checks << check("allocation_workbench_exists", allocation_workbench_exists?) if at_least?("slice_c")
      checks << check("sourcing_vendor_cards_exist", sourcing_vendor_cards_exist?) if at_least?("slice_d")
      checks << check("demand_to_po_services_exist", demand_to_po_services_exist?) if at_least?("slice_e")
      checks << check("demand_to_po_routes_exist", demand_to_po_routes_exist?) if at_least?("slice_e")
      checks << check("receipt_pickup_visibility_exists", receipt_pickup_visibility_exists?) if at_least?("slice_f")
      checks << check("pos_pickup_paths_exist", pos_pickup_paths_exist?) if at_least?("slice_g")
      if at_least?("final")
        checks << check("demand_show_next_action", next_action_partial_exists? && workflow_presenter_exists?)
        checks << check("inbound_workbench_no_raw_id_form", allocation_workbench_exists?)
        checks << check("sourcing_vendor_cards", sourcing_vendor_cards_exist?)
        checks << check("demand_to_po_bridge", demand_to_po_services_exist? && demand_to_po_routes_exist?)
        checks << check("receipt_pickup_visibility", receipt_pickup_visibility_exists?)
        checks << check("pos_pickup_flow", pos_pickup_paths_exist?)
        checks << check("no_legacy_ordering_reintroduced", no_legacy_ordering_reintroduced?)
      end

      failed = checks.reject { |c| c[:pass] }
      if failed.any?
        puts "V00412 verify FAILED (slice=#{slice}):"
        failed.each { |c| puts "  - #{c[:key]}: #{c[:message]}" }
        exit(1) if strict?
        return false
      end

      puts "V00412 verify PASS (slice=#{slice}, #{checks.size} checks)"
      true
    end

    def check(key, pass, message = nil)
      { key: key, pass: pass, message: message || key }
    end

    def strict?
      ActiveModel::Type::Boolean.new.cast(ENV.fetch("STRICT", false))
    end
  end
end
