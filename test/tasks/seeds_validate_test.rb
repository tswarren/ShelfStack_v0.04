# frozen_string_literal: true

require "test_helper"

class SeedsValidateTaskTest < ActiveSupport::TestCase
  test "production seed csv files pass validation" do
    require Rails.root.join("db/seeds/concerns/csv_seed_validator")

    result = Seeds::CsvSeedValidator.call
    assert result.ok?, result.errors.join("\n")
  end
end
