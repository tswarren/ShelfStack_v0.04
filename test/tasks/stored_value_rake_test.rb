# frozen_string_literal: true

require "test_helper"
require "rake"

class StoredValueRakeTest < ActiveSupport::TestCase
  setup do
    seed_phase7b_reference_data!
    @store = create_store!
    @user = create_user!
    grant_permission!(@user, "stored_value.admin.rebuild_balances")
    @account = create_stored_value_account!(issuing_store: @store)
    StoredValue::Issue.call(
      account: @account, store: @store, actor: @user, amount_cents: 300, reason_code: stored_value_reason_code!
    )
    Rails.application.load_tasks if Rake::Task.tasks.empty?
  end

  test "rebuild_balances rake task" do
    @account.update_column(:current_balance_cents, 0)
    ENV["USERNAME"] = @user.username
    capture_io do
      Rake::Task["shelfstack:stored_value:rebuild_balances"].reenable
      Rake::Task["shelfstack:stored_value:rebuild_balances"].invoke
    end
    assert_equal 300, @account.reload.current_balance_cents
  ensure
    ENV.delete("USERNAME")
  end

  test "integrity_check rake task passes" do
    output = capture_io do
      Rake::Task["shelfstack:stored_value:integrity_check"].reenable
      Rake::Task["shelfstack:stored_value:integrity_check"].invoke
    end
    assert_includes output, "Stored value integrity check passed."
  end

  private

  def capture_io
    original_stdout = $stdout
    buffer = StringIO.new
    $stdout = buffer
    yield
    buffer.string
  ensure
    $stdout = original_stdout
  end
end
