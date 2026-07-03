# frozen_string_literal: true

module Orders
  class ReceiptLineMatchesController < BaseController
    before_action :set_receipt
    before_action -> { authorize!("orders.receipts.update") }, only: %i[create destroy apply_suggestions]
    before_action :ensure_draft_receipt!

    def create
      Receiving::ApplyReceiptLineMatches.call!(
        receipt: @receipt,
        actor: current_user,
        matches: match_params
      )
      redirect_to orders_receipt_path(@receipt), notice: "Receipt line matches confirmed."
    rescue Receiving::ApplyReceiptLineMatches::ApplyError => e
      redirect_to orders_receipt_path(@receipt), alert: e.message
    end

    def apply_suggestions
      suggestions = Receiving::SuggestReceiptLineMatches.call(receipt: @receipt)
      matches = suggestions.map do |suggestion|
        {
          receipt_line_id: suggestion.receipt_line.id,
          purchase_order_line_id: suggestion.purchase_order_line.id,
          quantity_matched: suggestion.quantity_matched,
          match_source: suggestion.match_source
        }
      end

      if matches.empty?
        redirect_to orders_receipt_path(@receipt), alert: "No PO line matches were suggested."
        return
      end

      Receiving::ApplyReceiptLineMatches.call!(receipt: @receipt, actor: current_user, matches: matches)
      redirect_to orders_receipt_path(@receipt), notice: "Suggested PO line matches applied."
    rescue Receiving::ApplyReceiptLineMatches::ApplyError => e
      redirect_to orders_receipt_path(@receipt), alert: e.message
    end

    def destroy
      match = @receipt.receipt_line_matches.find(params[:id])
      match.update!(
        match_status: "released",
        released_at: Time.current,
        released_by_user: current_user,
        release_reason: params[:release_reason].presence || "Released by staff"
      )
      record_audit!("receipt_line_match.released", match)
      redirect_to orders_receipt_path(@receipt), notice: "Receipt line match released."
    end

    private

    def set_receipt
      @receipt = Receipt.where(store: orders_store).find(params[:receipt_id])
    end

    def ensure_draft_receipt!
      return if @receipt.draft?

      redirect_to orders_receipt_path(@receipt), alert: "Only draft receipts can be matched."
    end

    def match_params
      Array(params[:matches]).map do |entry|
        entry.permit(:receipt_line_id, :purchase_order_line_id, :quantity_matched, :match_source, :idempotency_key)
              .to_h
              .symbolize_keys
      end
    end
  end
end
