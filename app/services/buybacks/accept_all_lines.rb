# frozen_string_literal: true

module Buybacks
  class AcceptAllLines
    def self.call!(session:, actor:)
      new(session:, actor:).call!
    end

    def initialize(session:, actor:)
      @session = session
      @actor = actor
    end

    def call!
      session.buyback_lines.where(status: %w[offered priced]).find_each do |line|
        RecordCustomerDecision.call!(line:, session:, actor:, outcome: "accepted_by_customer")
      end
    end

    private

    attr_reader :session, :actor
  end
end
