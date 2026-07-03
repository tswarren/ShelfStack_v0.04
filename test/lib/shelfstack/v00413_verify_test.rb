# frozen_string_literal: true

require "test_helper"

class ShelfstackV00413VerifyTest < ActiveSupport::TestCase
  test "slice_0 checks pass with spec bundle" do
    with_env("V00413_SLICE" => "slice_0", "STRICT" => "1") do
      assert Shelfstack::V00413Verify.run!
    end
  end

  test "final checks pass when MVP implemented" do
    with_env("V00413_SLICE" => "final", "STRICT" => "1") do
      assert Shelfstack::V00413Verify.run!
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
