# frozen_string_literal: true

require "test_helper"

class ShelfstackV00412VerifyTest < ActiveSupport::TestCase
  test "slice_0 checks pass with spec bundle" do
    with_env("V00412_SLICE" => "slice_0", "STRICT" => "1") do
      assert Shelfstack::V00412Verify.run!
    end
  end

  test "final checks include workflow and PO bridge when slice is final" do
    with_env("V00412_SLICE" => "final", "STRICT" => "0") do
      assert Shelfstack::V00412Verify.at_least?("final")
      assert Shelfstack::V00412Verify.workflow_presenter_exists?
    end
  end

  private

  def with_env(vars)
    old = vars.keys.index_with { |key| ENV[key] }
    vars.each { |key, value| ENV[key] = value }
    yield
  ensure
    old.each do |key, value|
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
  end
end
