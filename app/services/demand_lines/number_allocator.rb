# frozen_string_literal: true

module DemandLines
  class NumberAllocator
    def self.next_for!(store:)
      new(store: store).next_for!
    end

    def initialize(store:)
      @store = store
    end

    def next_for!
      sequence = DemandLineSequence.transaction do
        record = DemandLineSequence.lock.find_or_create_by!(store: store)
        record.increment!(:last_sequence)
        record.last_sequence
      end

      format("%s-D%06d", store.store_number, sequence)
    end

    private

    attr_reader :store
  end
end
