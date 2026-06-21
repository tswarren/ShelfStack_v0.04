# frozen_string_literal: true

module CustomerRequests
  class Create
    class CreateError < StandardError; end

    def self.call(store:, created_by_user:, attributes:, lines: [])
      new(store:, created_by_user:, attributes:, lines:).call
    end

    def initialize(store:, created_by_user:, attributes:, lines: [])
      @store = store
      @created_by_user = created_by_user
      @attributes = attributes
      @lines = Array(lines)
    end

    def call
      request = nil
      CustomerRequest.transaction do
        request = CustomerRequest.new(attributes.merge(
          store: store,
          created_by_user: created_by_user,
          status: "new",
          request_number: RequestNumberAssigner.next_for!(store: store)
        ))
        lines.each_with_index do |line_attrs, index|
          request.customer_request_lines.build(line_attrs.merge(line_number: index + 1, status: "new"))
        end
        request.save!

        AuditEvents.record!(
          actor: created_by_user,
          event_name: "customer_request.created",
          auditable: request,
          details: {
            "request_number" => request.request_number,
            "line_count" => request.customer_request_lines.size
          }
        )
      end
      request
    end

    private

    attr_reader :store, :created_by_user, :attributes, :lines
  end
end
