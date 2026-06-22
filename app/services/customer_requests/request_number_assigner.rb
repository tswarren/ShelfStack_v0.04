# frozen_string_literal: true

module CustomerRequests
  class RequestNumberAssigner
    def self.next_for!(store:)
      new(store: store).next_for!
    end

    def self.call!(request)
      request.update!(request_number: next_for!(store: request.store))
      request.request_number
    end

    def initialize(store: nil, request: nil)
      @store = store || request.store
      @request = request
    end

    def next_for!
      store_number = store.store_number

      sequence = CustomerRequestSequence.transaction do
        record = CustomerRequestSequence.lock.find_or_create_by!(store: store)
        record.increment!(:last_sequence)
        record.last_sequence
      end

      format("REQ-%s-%06d", store_number, sequence)
    end

    private

    attr_reader :store, :request
  end
end
