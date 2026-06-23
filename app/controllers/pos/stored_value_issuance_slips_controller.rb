# frozen_string_literal: true

module Pos
  class StoredValueIssuanceSlipsController < BaseController
    before_action -> { authorize_pos!("pos.receipts.view") }, only: %i[show]
    before_action -> { authorize_pos!("pos.receipts.print") }, only: %i[print]
    before_action :set_slip_context

    def show
      @presenter = Pos::StoredValueIssuanceSlipPresenter.new(
        transaction: @transaction,
        ledger_entry: @ledger_entry,
        receipt: @receipt
      )
    end

    def print
      record_audit!("pos.stored_value_slip.printed", @ledger_entry)

      respond_to do |format|
        format.html { redirect_to pos_stored_value_issuance_slip_path(@ledger_entry) }
        format.turbo_stream { head :no_content }
      end
    end

    private

    def set_slip_context
      @ledger_entry = StoredValueLedgerEntry
        .includes(:stored_value_account, source: [ :stored_value_identifier, :pos_transaction ])
        .where(store_id: pos_store.id)
        .find(params[:id])
      raise ActiveRecord::RecordNotFound unless @ledger_entry.entry_type == "issue"

      @source = @ledger_entry.source
      @transaction = resolve_transaction
      raise ActiveRecord::RecordNotFound if @transaction.blank? || !@transaction.completed?

      @receipt = @transaction.pos_receipt
      verify_slip_eligible!
    end

    def resolve_transaction
      case @source
      when PosTransactionLine
        @source.pos_transaction
      when PosTender
        @source.pos_transaction
      end
    end

    def verify_slip_eligible!
      case @source
      when PosTransactionLine
        raise ActiveRecord::RecordNotFound unless @source.gift_card_sale_line?
      when PosTender
        unless @source.stored_value_tender? && StoredValueTenderSupport.issue_tender?(transaction: @transaction, tender: @source)
          raise ActiveRecord::RecordNotFound
        end
      else
        raise ActiveRecord::RecordNotFound
      end
    end
  end
end
