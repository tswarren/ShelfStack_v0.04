# frozen_string_literal: true

require "test_helper"

class SourcingAttemptStatusDeriverTest < ActiveSupport::TestCase
  include Phase3TestHelper
  include V0048TestHelper

  setup do
    @store = create_store!
    @user = create_user!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @attempt = SourcingAttempt.new(quantity_requested: 3)
  end

  def preview(**quantities)
    VendorResponse.new(sourcing_attempt: @attempt, **quantities)
  end

  test "response_status unavailable for all-unavailable final response" do
    status = Sourcing::AttemptStatusDeriver.response_status_from_quantities(
      preview(quantity_unavailable: 3)
    )

    assert_equal "unavailable", status
  end

  test "response_status canceled for all-canceled final response" do
    status = Sourcing::AttemptStatusDeriver.response_status_from_quantities(
      preview(quantity_canceled: 3)
    )

    assert_equal "canceled", status
  end

  test "response_status substitute_offered for substitute-only final response" do
    status = Sourcing::AttemptStatusDeriver.response_status_from_quantities(
      preview(quantity_substitute_offered: 3)
    )

    assert_equal "substitute_offered", status
  end

  test "response_status partially_confirmed when confirmed with remainder buckets" do
    status = Sourcing::AttemptStatusDeriver.response_status_from_quantities(
      preview(quantity_confirmed: 1, quantity_unavailable: 2)
    )

    assert_equal "partially_confirmed", status
  end

  test "response_status mixed for backordered and unavailable without confirmed" do
    status = Sourcing::AttemptStatusDeriver.response_status_from_quantities(
      preview(quantity_backordered: 2, quantity_unavailable: 1)
    )

    assert_equal "mixed", status
  end

  test "attempt status failed for all-unavailable final response" do
    response = preview(quantity_unavailable: 3)

    assert_equal "failed", Sourcing::AttemptStatusDeriver.from_final_response(response)
  end

  test "attempt status canceled for all-canceled final response" do
    response = preview(quantity_canceled: 3)

    assert_equal "canceled", Sourcing::AttemptStatusDeriver.from_final_response(response)
  end

  test "attempt status failed for substitute-only final response" do
    response = preview(quantity_substitute_offered: 3)

    assert_equal "failed", Sourcing::AttemptStatusDeriver.from_final_response(response)
  end

  test "attempt status partially_confirmed for confirmed with unavailable remainder" do
    response = preview(quantity_confirmed: 1, quantity_unavailable: 2)

    assert_equal "partially_confirmed", Sourcing::AttemptStatusDeriver.from_final_response(response)
  end

  test "attempt status failed for backordered and unavailable without confirmed" do
    response = preview(quantity_backordered: 2, quantity_unavailable: 1)

    assert_equal "failed", Sourcing::AttemptStatusDeriver.from_final_response(response)
  end
end
