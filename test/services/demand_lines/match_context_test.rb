# frozen_string_literal: true

require "test_helper"

class DemandLinesMatchContextTest < ActiveSupport::TestCase
  include V0047TestHelper

  setup do
    seed_v0047_permissions!
    @store = create_store!
    @user = create_user!
    @demand_line = DemandLines::CreateFromProvisional.call!(
      store: @store,
      actor: @user,
      customer: create_customer!,
      provisional_title: "Unknown Title",
      quantity: 1
    )
  end

  test "valid when captured demand line is present" do
    context = DemandLines::MatchContext.new(
      return_to: DemandLines::MatchContext::RETURN_TO,
      demand_line_id: @demand_line.id,
      store: @store
    )

    assert context.valid?
    assert_includes context.banner_label, @demand_line.demand_number
  end
end
