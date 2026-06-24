# frozen_string_literal: true

module Buybacks
  class DonateDeclinedLines
    def self.call!(session:, actor:)
      new(session:, actor:).call!
    end

    def initialize(session:, actor:)
      @session = session
      @actor = actor
    end

    def call!
      session.buyback_lines.where(outcome: "declined_by_customer", status: "decided").find_each do |line|
        RecordCustomerDecision.call!(line:, session:, actor:, outcome: "donated_by_customer")
      end
    end

    private

    attr_reader :session, :actor
  end
end
