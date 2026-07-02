# frozen_string_literal: true

module Purchasing
  module ReceiptPostingGuards
    module_function

    def assert_no_mixed_claims!(_receipt)
      # Legacy mixed-claim guard removed in v0.04-10 G2.
    end
  end
end
