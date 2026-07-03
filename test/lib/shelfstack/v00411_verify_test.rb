# frozen_string_literal: true

require "test_helper"

class ShelfstackV00411VerifyTest < ActiveSupport::TestCase
  test "report includes required check keys" do
    result = Shelfstack::V00411Verify.report(strict: false)

    %i[
      v00410_completion_marked_complete
      active_docs_no_forbidden_legacy_models
      schema_reference_no_dropped_ordering_tables
      domain_model_describes_v004_chain
      glossary_has_retired_section
      agents_md_references_v004_verifiers
      v004_milestone_statuses_aligned
      redirect_aliases_allowlisted
      app_no_dropped_ordering_model_constants
    ].each do |key|
      assert_includes result[:checks].keys, key
    end
  end

  test "allowlist permits retired historical reference" do
    assert Shelfstack::V00411Verify.line_allowlisted?("Retired v0.03: customer_requests → DemandLine")
    assert Shelfstack::V00411Verify.line_allowlisted?("Retained temporary legacy admin surface for catalog_items")
  end

  test "forbidden term scanner flags sample stale string" do
    refute Shelfstack::V00411Verify.line_allowlisted?("CustomerRequest is the active demand document.")
  end

  test "report passes on current repo after v0.04-11 docs" do
    result = Shelfstack::V00411Verify.report(strict: true)

    assert_equal "PASS", result[:status], result[:failures].inspect
  end
end
