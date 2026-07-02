# frozen_string_literal: true

module Phase7aTestHelper
  LegacyCustomerRequest = Struct.new(:demand_lines, keyword_init: true) do
    def request_number
      demand_lines.first&.demand_number
    end

    def customer_request_lines
      demand_lines
    end

    def id
      demand_lines.first&.id
    end

    def update!(attrs)
      demand_lines.each { |line| line.update!(attrs) }
      self
    end
  end

  REQUEST_TYPE_TO_CAPTURE_INTENT = {
    "research" => "research",
    "hold" => "hold",
    "notify" => "notify",
    "special_order" => "special_order"
  }.freeze

  def grant_all_phase7a_permissions!(user, store: nil)
    Seeds::Phase7aPermissions::PERMISSIONS.each do |attrs|
      grant_permission!(user, attrs[:key], store: store)
    end
  end

  def create_customer!(attrs = {})
    Customer.create!(
      {
        display_name: "Test Customer #{SecureRandom.hex(3)}",
        email: "customer#{SecureRandom.hex(3)}@example.com",
        phone: "555-0100",
        active: true
      }.merge(attrs)
    )
  end

  def create_customer_request!(store:, created_by_user:, customer: nil, lines: [ {} ])
    demand_lines = lines.map do |line_attrs|
      line = {
        request_type: "research",
        requested_quantity: 1,
        provisional_title: "Test Title"
      }.merge(line_attrs.symbolize_keys)

      capture_intent = REQUEST_TYPE_TO_CAPTURE_INTENT.fetch(line[:request_type].to_s, "research")
      quantity = line[:requested_quantity].to_i
      quantity = 1 if quantity <= 0
      variant = line[:product_variant] || line[:variant]

      if variant.present?
        DemandLines::Create.call!(
          store: store,
          actor: created_by_user,
          capture_intent: capture_intent,
          quantity: quantity,
          variant: variant,
          customer: customer,
          customer_name_snapshot: customer&.display_name || line[:customer_name_snapshot] || "Walk-in Customer",
          provisional_title: line[:provisional_title],
          source: line[:source] || "in_store"
        )
      elsif capture_intent == "research"
        DemandLines::CreateFromProvisional.call!(
          store: store,
          actor: created_by_user,
          customer: customer,
          customer_name_snapshot: customer&.display_name || line[:customer_name_snapshot] || "Walk-in Customer",
          provisional_title: line[:provisional_title] || "Test Title",
          quantity: quantity
        )
      else
        DemandLines::CreateFromProvisional.call!(
          store: store,
          actor: created_by_user,
          customer: customer,
          customer_name_snapshot: customer&.display_name || line[:customer_name_snapshot] || "Walk-in Customer",
          provisional_title: line[:provisional_title] || "Test Title",
          quantity: quantity,
          notes: "__pending_intent:#{capture_intent}__"
        )
      end
    end

    LegacyCustomerRequest.new(demand_lines: demand_lines)
  end

  def match_request_line!(line:, variant:, actor:)
    demand_line = line
    matched = DemandLines::MatchVariant.call!(demand_line: demand_line, variant: variant, actor: actor)

    pending_intent = demand_line.notes&.match(/__pending_intent:(\w+)__/)&.captures&.first
    if pending_intent.present?
      matched.update!(capture_intent: pending_intent, notes: demand_line.notes.sub(/__pending_intent:\w+__\s*/, "").presence)
    end

    matched
  end

  def create_hold_with_on_hand_allocation!(store:, actor:, variant:, customer: nil, quantity: 1)
    result = DemandLines::StartFromItem.call!(
      store: store,
      variant: variant,
      actor: actor,
      capture_intent: "hold",
      quantity: quantity,
      customer: customer || create_customer!
    )
    result.demand_line
  end

  def create_manual_tbo_demand!(store:, actor:, variant:, quantity: 1, **attrs)
    DemandLines::Create.call!(
      store: store,
      actor: actor,
      capture_intent: "manual_tbo",
      variant: variant,
      quantity: quantity,
      **attrs
    )
  end
end
