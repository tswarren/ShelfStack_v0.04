# frozen_string_literal: true

module Pos
  class VoidDiscountApplication
    Error = Class.new(StandardError)

    def self.call!(application:, actor:, void_reason: nil)
      new(application:, actor:, void_reason:).call!
    end

    def initialize(application:, actor:, void_reason: nil)
      @application = application
      @actor = actor
      @void_reason = void_reason
    end

    def call!
      transaction = application.pos_transaction
      raise Error, "Transaction is not editable." unless transaction.editable?
      raise Error, "Discount application is already voided." if application.voided?

      transaction.transaction do
        application.update!(
          voided_at: Time.current,
          voided_by_user: actor,
          void_reason: void_reason
        )
        DiscountRecalculator.call!(transaction)
      end

      application.reload
    end

    private

    attr_reader :application, :actor, :void_reason
  end
end
