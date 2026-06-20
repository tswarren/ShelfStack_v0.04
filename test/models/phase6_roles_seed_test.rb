# frozen_string_literal: true

require "test_helper"
require_relative "../../db/seeds/phase6_roles"

class Phase6RolesSeedTest < ActiveSupport::TestCase
  setup do
    Seeds::Phase6Permissions.seed!
  end

  test "phase6 role bundles are idempotent and grant expected permissions" do
    Seeds::Phase6Roles.seed!
    cashier = Role.find_by!(role_key: "pos_cashier")
    lead = Role.find_by!(role_key: "pos_lead")
    manager = Role.find_by!(role_key: "pos_manager")

    assert_equal "POS Cashier", cashier.name
    assert_equal "POS Lead Cashier", lead.name
    assert_equal "POS Manager", manager.name

    assert cashier.permissions.exists?(permission_key: "pos.access")
    assert cashier.permissions.exists?(permission_key: "pos.transactions.complete")
    refute cashier.permissions.exists?(permission_key: "pos.transactions.void")

    assert lead.permissions.exists?(permission_key: "pos.returns.no_receipt")
    assert lead.permissions.exists?(permission_key: "pos.lines.sell_inactive")

    assert manager.permissions.exists?(permission_key: "pos.transactions.void")
    assert manager.permissions.exists?(permission_key: "pos.register_sessions.force_close")

    Seeds::Phase6Roles.seed!
    assert_equal cashier.permissions.count, Role.find_by!(role_key: "pos_cashier").permissions.count
  end
end
