# frozen_string_literal: true

module Phase7aTestHelper
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

  def create_customer_request!(store:, created_by_user:, customer: nil, lines: [{}])
    CustomerRequests::Create.call(
      store: store,
      created_by_user: created_by_user,
      attributes: {
        customer: customer,
        customer_name_snapshot: customer&.display_name || "Walk-in Customer",
        source: "in_store"
      },
      lines: lines.map do |line|
        {
          request_type: "research",
          requested_quantity: 1,
          provisional_title: "Test Title"
        }.merge(line)
      end
    )
  end

  def match_request_line!(line:, variant:, actor:)
    CustomerRequests::MatchVariant.call!(line: line, variant: variant, actor: actor)
  end
end
