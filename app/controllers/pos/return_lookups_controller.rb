# frozen_string_literal: true

module Pos
  class ReturnLookupsController < BaseController
    before_action -> { authorize_pos!("pos.returns.receipted") }

    def show
      result = Pos::ReturnLookup.call(store: pos_store, transaction_number: params[:transaction_number])

      render json: {
        status: result.status.to_s,
        message: result.message,
        transaction: result.transaction && {
          id: result.transaction.id,
          transaction_number: result.transaction.transaction_number,
          completed_at: result.transaction.completed_at
        },
        lines: result.lines
      }
    end
  end
end
