# frozen_string_literal: true

module Buybacks
  class DeclineAllLines
    def self.call!(session:, actor:)
      new(session:, actor:).call!
    end

    def initialize(session:, actor:)
      @session = session
      @actor = actor
    end

    def call!
      if session.buyback_lines.where(status: "priced").exists?
        raise RecordCustomerDecision::Error,
              "Repriced lines must be saved back into the proposal before batch decline."
      end

      session.buyback_lines.where(status: "offered").find_each do |line|
        RecordCustomerDecision.call!(line:, session:, actor:, outcome: "declined_by_customer")
      end
    end

    private

    attr_reader :session, :actor
  end
end
