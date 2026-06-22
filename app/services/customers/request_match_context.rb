# frozen_string_literal: true

module Customers
  class RequestMatchContext
    RETURN_TO = "from_customer_request"

    def self.from_params(params, store:)
      new(
        return_to: params[:return_to],
        customer_request_id: params[:customer_request_id],
        line_id: params[:line_id],
        store: store
      )
    end

    def initialize(return_to:, customer_request_id:, line_id:, store:)
      @return_to = return_to.to_s
      @customer_request_id = customer_request_id.presence
      @line_id = line_id.presence
      @store = store
    end

    def active?
      from_customer_request? && customer_request_id.present? && line_id.present?
    end

    def from_customer_request?
      @return_to == RETURN_TO
    end

    attr_reader :customer_request_id, :line_id, :store

    def request_record
      return @request_record if defined?(@request_record)

      @request_record = active? ? CustomerRequest.find_by(id: customer_request_id, store: store) : nil
    end

    alias customer_request_record request_record

    def line
      return @line if defined?(@line)

      @line = if request_record.present?
        request_record.customer_request_lines.find_by(id: line_id)
      end
    end

    def valid?
      return false unless active?
      return false if request_record.blank?
      return false if line.blank?
      return false if terminal_line?

      true
    end

    def terminal_line?
      line.present? && line.status.in?(%w[completed cancelled unfillable])
    end

    def matched?
      line&.matched?
    end

    def param_hash
      return {} unless active?

      {
        return_to: RETURN_TO,
        customer_request_id: customer_request_id,
        line_id: line_id
      }
    end

    def return_path(anchor: true)
      return nil unless request_record.present?

      path = Rails.application.routes.url_helpers.customers_customer_request_path(request_record)
      path = "#{path}#line-#{line_id}" if anchor && line_id.present?
      path
    end

    def banner_label
      return nil unless valid?

      item_label = line.provisional_title.presence || line.provisional_identifier.presence || "Line #{line.line_number}"
      "Matching #{request_record.request_number} · Line #{line.line_number}: #{item_label}"
    end
  end
end
