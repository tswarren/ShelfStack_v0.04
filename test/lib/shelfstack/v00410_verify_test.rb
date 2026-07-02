# frozen_string_literal: true

require "test_helper"

class ShelfstackV00410VerifyTest < ActiveSupport::TestCase
  test "report includes g1 checks by default" do
    result = Shelfstack::V00410Verify.report(strict: false)

    assert_equal "g1", result[:phase]
    assert_includes result[:checks].keys, :pos_demand_allocation_column_present
    assert_includes result[:checks].keys, :demand_pickup_services_present
  end

  test "g2 phase includes legacy table checks" do
    with_env("V00410_PHASE" => "g2") do
      result = Shelfstack::V00410Verify.report(strict: false)

      assert_equal "g2", result[:phase]
      assert_includes result[:checks].keys, :legacy_tables_absent
    end
  end

  private

  def with_env(updates)
    previous = updates.keys.index_with { |key| ENV[key] }
    updates.each { |key, value| ENV[key] = value }
    yield
  ensure
    previous.each do |key, value|
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
  end
end
