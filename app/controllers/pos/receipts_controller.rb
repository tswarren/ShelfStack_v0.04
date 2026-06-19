# frozen_string_literal: true

module Pos
  class ReceiptsController < BaseController
    before_action -> { authorize_pos!("pos.receipts.view") }, only: %i[show]
    before_action -> { authorize_pos!("pos.receipts.print") }, only: %i[print]

    def show
      @receipt = PosReceipt.where(store: pos_store).find(params[:id])
      @transaction = @receipt.pos_transaction
      @transaction.pos_transaction_lines.includes(:tax_category).load
      @transaction.pos_tenders.load
    end

    def print
      @receipt = PosReceipt.where(store: pos_store).find(params[:id])
      @receipt.increment!(:reprint_count)
      record_audit!("pos.receipt.printed", @receipt)
      redirect_to pos_receipt_path(@receipt), notice: "Receipt reprinted."
    end
  end
end
