# frozen_string_literal: true

module Pos
  class TransactionNumberAssigner
    def self.call!(transaction)
      new(transaction).call!
    end

    def initialize(transaction)
      @transaction = transaction
    end

    def call!
      raise ArgumentError, "transaction already numbered" if transaction.transaction_number.present?

      store_number = transaction.store.store_number
      workstation_number = transaction.workstation.workstation_number

      sequence = PosWorkstationSequence.transaction do
        record = PosWorkstationSequence.lock.find_or_create_by!(workstation: transaction.workstation)
        record.increment!(:last_sequence)
        record.last_sequence
      end

      number = format("%s-%s-%06d", store_number, workstation_number, sequence)
      transaction.update!(transaction_number: number)
      number
    end

    private

    attr_reader :transaction
  end
end
