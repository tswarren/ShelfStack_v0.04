# frozen_string_literal: true

module Buybacks
  class AcceptLine
    class Error < StandardError; end

    def self.call!(**)
      raise Error, "AcceptLine is deprecated. Use UpdateProposalLine, SaveProposal, and RecordCustomerDecision."
    end
  end
end
