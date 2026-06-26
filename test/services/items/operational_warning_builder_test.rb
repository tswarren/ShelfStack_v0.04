# frozen_string_literal: true

require "test_helper"

class Items::OperationalWarningBuilderTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
  end

  test "delegates ordering warnings from eligibility resolver" do
    warnings = Items::OperationalWarningBuilder.call(product_variant: @variant, contexts: [ :ordering ])

    assert warnings.any? { |warning| warning.category == :ordering }
    assert warnings.any? { |warning| warning.code == :missing_preferred_vendor }
  end
end
