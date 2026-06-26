# frozen_string_literal: true

require "test_helper"

class Reports::RegistryTest < ActiveSupport::TestCase
  test "all reports have unique keys" do
    keys = Reports::Registry.all.map(&:key)
    assert_equal keys.size, keys.uniq.size
  end

  test "permitted_for returns reports matching authorization" do
    user = create_user!(username: "registry#{SecureRandom.hex(3)}")
    store = create_store!
    grant_permission!(user, "pos.reports.sales", store: store)

    permitted = Reports::Registry.permitted_for(user: user, store: store)
    assert permitted.any? { |report| report.key == :sales }
    assert_not permitted.any? { |report| report.key == :buyback_summary }
  end
end
