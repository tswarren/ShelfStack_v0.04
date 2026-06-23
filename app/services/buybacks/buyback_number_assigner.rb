# frozen_string_literal: true

module Buybacks
  class BuybackNumberAssigner
    def self.call!(session:)
      new(session:).call!
    end

    def initialize(session:)
      @session = session
    end

    def call!
      raise ArgumentError, "session already numbered" if session.buyback_number.present?
      raise ArgumentError, "workstation is required" if session.workstation.blank?

      store_number = session.store.store_number
      workstation_number = session.workstation.workstation_number

      sequence = BuybackSequence.transaction do
        record = BuybackSequence.lock.find_or_create_by!(workstation: session.workstation)
        record.increment!(:last_sequence)
        record.last_sequence
      end

      number = format("%s-%s-B%06d", store_number, workstation_number, sequence)
      session.update!(buyback_number: number)
      number
    end

    private

    attr_reader :session
  end
end
