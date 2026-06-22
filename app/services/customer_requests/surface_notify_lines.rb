# frozen_string_literal: true

module CustomerRequests
  class SurfaceNotifyLines
    def self.for_variant(store:, variant:, actor: nil)
      new(store:, variant:, actor:).call
    end

    def initialize(store:, variant:, actor: nil)
      @store = store
      @variant = variant
      @actor = actor
    end

    def call
      return unless Inventory::Availability.available(store: store, variant: variant).to_i.positive?

      matching_lines.each do |line|
        next unless line.status == "matched"
        next if NotifyQueueQuery.fully_reserved?(line)

        line.update!(status: "ready_for_pickup")
        line.customer_request.refresh_status_from_lines!
      end
    end

    private

    attr_reader :store, :variant, :actor

    def matching_lines
      CustomerRequestLine.open_lines
                         .where(request_type: "notify", product_variant: variant)
                         .joins(:customer_request)
                         .where(customer_requests: { store_id: store.id })
    end
  end
end
