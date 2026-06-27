# frozen_string_literal: true

require "test_helper"

class Pos::CommandBarRouterTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @variant = create_product_variant!(selling_price_cents: 1000)
    @user = create_user!
    @workstation = create_workstation!(store: @store)
    @register_session = open_register_session!(store: @store, workstation: @workstation, user: @user)
    grant_all_phase6_permissions!(@user, store: @store)
    grant_pos_stored_value_tender_permissions!(@user, store: @store)
  end

  test "variant lookup wins over receipt-shaped input" do
    sku = @variant.sku
    route = Pos::CommandBarRouter.call(store: @store, input: sku)

    assert_equal :variant_lookup, route.action
    assert route.payload[:variants].any?
  end

  test "receipt-shaped input returns failed lookup message when no variant match" do
    route = Pos::CommandBarRouter.call(store: @store, input: "001-001-000042")

    assert_equal :message, route.action
    assert_equal Pos::CommandParser::FAILED_LOOKUP_MESSAGE, route.message
  end

  test "unmatched non-receipt input returns failed lookup message" do
    route = Pos::CommandBarRouter.call(store: @store, input: "Custom gift wrap")

    assert_equal :message, route.action
    assert_equal Pos::CommandParser::FAILED_LOOKUP_MESSAGE, route.message
  end

  test "bare amount returns failed lookup message" do
    route = Pos::CommandBarRouter.call(store: @store, input: "20")

    assert_equal :message, route.action
    assert_equal Pos::CommandParser::FAILED_LOOKUP_MESSAGE, route.message
  end

  test "isbn lookup routes to variant lookup with multiple matches" do
    seed_phase3_reference_data!
    catalog_item = create_catalog_item!(title: "Router Multi Book")
    CatalogIdentifierService.add_identifier!(
      catalog_item: catalog_item,
      identifier_type: "isbn13",
      value: "9780143127741",
      primary: true
    )
    product = create_product!(catalog_item: catalog_item, sku: "9780143127741")
    variant = create_product_variant!(product: product, sub_department: @variant.sub_department, sku: "9780143127741", selling_price_cents: 1200)
    create_product_variant!(
      product: product,
      sub_department: @variant.sub_department,
      condition: ProductCondition.find_by!(condition_key: "used_good"),
      sku: "9780143127741UG",
      selling_price_cents: 800
    )

    route = Pos::CommandBarRouter.call(store: @store, input: "9780143127741")

    assert_equal :variant_lookup, route.action
    assert_equal :ambiguous, route.payload[:status]
    assert_equal 2, route.payload[:variants].size
    assert_includes route.payload[:variants].map(&:id), variant.id
  end

  test "long numeric barcode input does not treat scan as dollar amount" do
    route = Pos::CommandBarRouter.call(store: @store, input: "9780143127741")

    assert_nil route.payload[:amount_cents]
  end

  test "gift card command with amount opens gift card offer without auto-posting" do
    route = Pos::CommandBarRouter.call(
      store: @store,
      register_session: @register_session,
      user: @user,
      transaction: create_pos_transaction!(store: @store, workstation: @workstation, user: @user),
      input: "/giftcard 25"
    )

    assert_equal :gift_card_sale_offer, route.action
    assert_equal 2500, route.payload[:amount_cents]
  end

  test "gift card command without amount opens drawer offer" do
    route = Pos::CommandBarRouter.call(
      store: @store,
      register_session: @register_session,
      user: @user,
      transaction: create_pos_transaction!(store: @store, workstation: @workstation, user: @user),
      input: "/giftcard"
    )

    assert_equal :gift_card_sale_offer, route.action
  end

  test "balance command opens balance inquiry offer" do
    route = Pos::CommandBarRouter.call(
      store: @store,
      register_session: @register_session,
      input: "/balance"
    )

    assert_equal :balance_inquiry_offer, route.action
  end

  test "/d routes to previous discountable line when transaction provided" do
    transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [
        { product_variant: @variant, quantity: 1, unit_price_cents: 1000, extended_price_cents: 1000 },
        { product_variant: @variant, quantity: 1, unit_price_cents: 2000, extended_price_cents: 2000 }
      ]
    )
    previous_line = transaction.pos_transaction_lines.order(:line_number).last

    route = Pos::CommandBarRouter.call(
      store: @store,
      register_session: @register_session,
      transaction: transaction,
      input: "/d"
    )

    assert_equal :line_discount_offer, route.action
    assert_equal previous_line.id, route.payload[:line_id]
  end

  test "/d without transaction returns no active transaction message" do
    route = Pos::CommandBarRouter.call(
      store: @store,
      register_session: @register_session,
      input: "/d"
    )

    assert_equal :message, route.action
    assert_equal Pos::CommandRegistry::NO_ACTIVE_TRANSACTION_MESSAGE, route.message
  end

  test "/ld routes to line discount workflow" do
    transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [
        { product_variant: @variant, quantity: 1, unit_price_cents: 1000, extended_price_cents: 1000 }
      ]
    )

    route = Pos::CommandBarRouter.call(
      store: @store,
      register_session: @register_session,
      transaction: transaction,
      input: "/ld"
    )

    assert_equal :line_discount_offer, route.action
  end

  test "/di routes to transaction discount workflow" do
    transaction = create_pos_transaction!(store: @store, workstation: @workstation, user: @user)

    route = Pos::CommandBarRouter.call(
      store: @store,
      register_session: @register_session,
      transaction: transaction,
      input: "/di"
    )

    assert_equal :transaction_discount_offer, route.action
  end

  test "/cashdrop returns planned disabled message" do
    route = Pos::CommandBarRouter.call(
      store: @store,
      register_session: @register_session,
      input: "/cashdrop"
    )

    assert_equal :message, route.action
    assert_equal Pos::CommandRegistry::Catalog::CASH_DROP_UNAVAILABLE_MESSAGE, route.message
  end

  test "/d skips non-discountable previous line" do
    non_discountable_variant = create_product_variant!(
      sub_department: @variant.sub_department,
      sku: "DISC-NO-#{SecureRandom.hex(3)}",
      selling_price_cents: 1000,
      discountable: false
    )
    transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [
        { product_variant: @variant, quantity: 1, unit_price_cents: 1000, extended_price_cents: 1000 },
        { product_variant: non_discountable_variant, quantity: 1, unit_price_cents: 1000, extended_price_cents: 1000 }
      ]
    )
    discountable_line = transaction.pos_transaction_lines.order(:line_number).first

    route = Pos::CommandBarRouter.call(
      store: @store,
      register_session: @register_session,
      transaction: transaction,
      input: "/d"
    )

    assert_equal discountable_line.id, route.payload[:line_id]
  end

  test "open ring command opens offer panel payload" do
    route = Pos::CommandBarRouter.call(
      store: @store,
      register_session: @register_session,
      user: @user,
      transaction: create_pos_transaction!(store: @store, workstation: @workstation, user: @user),
      input: "/op 15"
    )

    assert_equal :open_ring_offer, route.action
    assert_equal 1500, route.payload[:amount_cents]
  end

  test "invalid open ring amount returns message" do
    route = Pos::CommandBarRouter.call(
      store: @store,
      register_session: @register_session,
      user: @user,
      input: "/op abc"
    )

    assert_equal :message, route.action
    assert_equal Pos::CommandRouteBuilder::INVALID_AMOUNT_MESSAGE, route.message
  end

  test "invalid gift card amount returns message" do
    route = Pos::CommandBarRouter.call(
      store: @store,
      register_session: @register_session,
      user: @user,
      input: "/gc abc"
    )

    assert_equal :message, route.action
    assert_equal Pos::CommandRouteBuilder::INVALID_AMOUNT_MESSAGE, route.message
  end

  test "return command opens return drawer offer" do
    transaction = create_pos_transaction!(store: @store, workstation: @workstation, user: @user)

    route = Pos::CommandBarRouter.call(
      store: @store,
      register_session: @register_session,
      user: @user,
      transaction: transaction,
      input: "/return"
    )

    assert_equal :return_drawer_offer, route.action
  end

  test "return alias with receipt prefills payload" do
    transaction = create_pos_transaction!(store: @store, workstation: @workstation, user: @user)

    route = Pos::CommandBarRouter.call(
      store: @store,
      register_session: @register_session,
      user: @user,
      transaction: transaction,
      input: "/rt 001-001-000042"
    )

    assert_equal :return_drawer_offer, route.action
    assert_equal "001-001-000042", route.payload[:receipt_number]
  end

  test "return command blocked when settlement rows exist" do
    transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [
        { product_variant: @variant, quantity: 1, unit_price_cents: 1000, extended_price_cents: 1000 }
      ]
    )
    create_pos_tender!(transaction, tender_type: "cash", amount_cents: 1000)

    route = Pos::CommandBarRouter.call(
      store: @store,
      register_session: @register_session,
      user: @user,
      transaction: transaction,
      input: "/return"
    )

    assert_equal :message, route.action
    assert_equal Pos::CommandRouteBuilder::RETURN_BLOCKED_TENDERS_MESSAGE, route.message
  end

  test "pickup command opens pickup drawer offer" do
    transaction = create_pos_transaction!(store: @store, workstation: @workstation, user: @user)

    route = Pos::CommandBarRouter.call(
      store: @store,
      register_session: @register_session,
      user: @user,
      transaction: transaction,
      input: "/pickup"
    )

    assert_equal :pickup_drawer_offer, route.action
  end

  test "register-session-required command without open session returns message" do
    route = Pos::CommandBarRouter.call(store: @store, register_session: nil, input: "/balance")

    assert_equal :message, route.action
    assert_equal Pos::CommandRegistry::NO_REGISTER_SESSION_MESSAGE, route.message
  end

  test "/help returns help action" do
    route = Pos::CommandBarRouter.call(store: @store, input: "/help")

    assert_equal :help, route.action
    assert_includes route.message, "POS commands:"
  end

  test "/? returns help action" do
    route = Pos::CommandBarRouter.call(store: @store, input: "/?")

    assert_equal :help, route.action
  end

  test "bare ? returns help action" do
    route = Pos::CommandBarRouter.call(store: @store, input: "?")

    assert_equal :help, route.action
  end

  test "unknown slash command returns unknown command message" do
    route = Pos::CommandBarRouter.call(store: @store, input: "/foo")

    assert_equal :message, route.action
    assert_equal Pos::CommandParser::UNKNOWN_COMMAND_MESSAGE, route.message
  end
end
