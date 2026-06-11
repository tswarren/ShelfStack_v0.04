ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "../db/seeds/phase1_permissions"
require_relative "../db/seeds/phase2_permissions"
require_relative "../db/seeds/phase3_permissions"
require_relative "support/phase1_test_helper"
require_relative "support/phase2_test_helper"
require_relative "support/phase3_test_helper"

module ActiveSupport
  class TestCase
    include Phase1TestHelper
    include Phase2TestHelper
    include Phase3TestHelper

    parallelize(workers: 1)

    setup do
      seed_minimal_permissions!
    end
  end
end

class ActionDispatch::IntegrationTest
  include Phase1TestHelper
  include Phase2TestHelper
  include Phase3TestHelper
end
