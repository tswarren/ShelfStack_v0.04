ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "../db/seeds/phase1_permissions"
require_relative "../db/seeds/phase2_permissions"
require_relative "../db/seeds/phase3_permissions"
require_relative "../db/seeds/phase3b_permissions"
require_relative "../db/seeds/phase4_permissions"
require_relative "../db/seeds/phase5_permissions"
require_relative "../db/seeds/phase6_permissions"
require_relative "../db/seeds/phase65_permissions"
require_relative "../db/seeds/phase7a_permissions"
require_relative "../db/seeds/phase7b_permissions"
require_relative "../db/seeds/phase7b_stored_value"
require_relative "../db/seeds/phase7c_permissions"
require_relative "../db/seeds/phase7c_buyback"
require_relative "../db/seeds/phase852_permissions"
require_relative "../db/seeds/v0046_permissions"
require_relative "../db/seeds/v0047_permissions"
require_relative "../db/seeds/v0048_permissions"
require_relative "../db/seeds/phase4_inventory"
require_relative "../db/seeds/phase5_inventory"
require_relative "support/phase1_test_helper"
require_relative "support/phase2_test_helper"
require_relative "support/phase3_test_helper"
require_relative "support/phase3b_test_helper"
require_relative "support/phase4_test_helper"
require_relative "support/phase5_test_helper"
require_relative "support/phase6_test_helper"
require_relative "support/phase65_test_helper"
require_relative "support/phase7a_test_helper"
require_relative "support/phase7b_test_helper"
require_relative "support/phase7c_test_helper"
require_relative "support/v0042_test_helper"
require_relative "support/v0047_test_helper"
require_relative "support/v0048_test_helper"
require_relative "support/v0049_test_helper"
require_relative "support/pos_system_test_helper"

module ActiveSupport
  class TestCase
    include Phase1TestHelper
    include Phase2TestHelper
    include Phase3TestHelper
    include Phase3bTestHelper
    include Phase4TestHelper
    include Phase5TestHelper
    include Phase6TestHelper
    include Phase65TestHelper
    include Phase7aTestHelper
    include Phase7bTestHelper
    include Phase7cTestHelper
    include V0042TestHelper
    include V0047TestHelper
    include V0048TestHelper

    parallelize(workers: 1)

    setup do
      seed_minimal_permissions!
      ensure_v0042_internal_ean_sequences!
    end
  end
end

class ActionDispatch::IntegrationTest
  include Phase1TestHelper
  include Phase2TestHelper
  include Phase3TestHelper
  include Phase3bTestHelper
  include Phase4TestHelper
  include Phase5TestHelper
  include Phase6TestHelper
  include Phase7aTestHelper
  include Phase7bTestHelper
  include Phase7cTestHelper
  include V0047TestHelper
  include V0048TestHelper
end
