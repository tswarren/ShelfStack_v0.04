# frozen_string_literal: true

module Buybacks
  class LineMatchContext
    RETURN_TO = "buyback_line"

    def self.from_params(params, store:)
      new(
        return_to: params[:return_to],
        buyback_session_id: params[:buyback_session_id],
        line_id: params[:line_id],
        store: store
      )
    end

    def self.from_draft(draft, store:)
      new(
        return_to: draft["return_to"],
        buyback_session_id: draft["buyback_session_id"],
        line_id: draft["buyback_line_id"],
        store: store
      )
    end

    def initialize(return_to:, buyback_session_id:, line_id:, store:)
      @return_to = return_to.to_s
      @buyback_session_id = buyback_session_id.presence
      @line_id = line_id.presence
      @store = store
    end

    def active?
      from_buyback_line? && buyback_session_id.present? && line_id.present?
    end

    def from_buyback_line?
      @return_to == RETURN_TO
    end

    attr_reader :buyback_session_id, :line_id, :store

    def session_record
      return @session_record if defined?(@session_record)

      @session_record = if active?
        BuybackSession.find_by(id: buyback_session_id, store: store)
      end
    end

    def line
      return @line if defined?(@line)

      @line = if session_record.present?
        session_record.buyback_lines.find_by(id: line_id)
      end
    end

    def valid?
      return false unless active?
      return false if session_record.blank?
      return false if line.blank?
      return false unless session_record.editable?

      true
    end

    def param_hash
      return {} unless active?

      {
        return_to: RETURN_TO,
        buyback_session_id: buyback_session_id,
        line_id: line_id
      }
    end

    def return_path(anchor: true)
      return nil unless session_record.present?

      path = Rails.application.routes.url_helpers.buybacks_session_path(session_record)
      anchor && line_id.present? ? "#{path}#line-#{line_id}" : path
    end

    def banner_label
      return nil unless valid?

      item_label = line.title_snapshot.presence || line.identifier_entered.presence || "Line #{line.line_number}"
      "Matching buyback #{session_record.buyback_number.presence || "##{session_record.id}"} · Line #{line.line_number}: #{item_label}"
    end
  end
end
