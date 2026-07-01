# frozen_string_literal: true

require "test_helper"

class Shelfstack::V0045VerifyTest < ActiveSupport::TestCase
  test "report includes condition and sku baseline fields" do
    seed_phase3_reference_data!
    Seeds::Phase7cBuyback.seed!

    report = Shelfstack::V0045Verify.report

    assert report[:new_condition_present]
    assert report[:buyback_default_valid]
    assert_empty report[:buyback_eligible_marked_new]
    assert report.key?(:used_like_orderable_variant_count)
    assert report.key?(:suffix_sku_generation_paths)
  end

  test "strict_failures empty on clean seeded data" do
    seed_phase3_reference_data!
    Seeds::Phase7cBuyback.seed!

    report = Shelfstack::V0045Verify.report
    failures = Shelfstack::V0045Verify.strict_failures(report)

    assert_empty failures, failures.join("; ")
  end
end
