# frozen_string_literal: true

module DemandLines
  class MatchContext
    RETURN_TO = "from_demand_line"

    def self.from_params(params, store:)
      new(
        return_to: params[:return_to],
        demand_line_id: params[:demand_line_id],
        store: store
      )
    end

    def initialize(return_to:, demand_line_id:, store:)
      @return_to = return_to.to_s
      @demand_line_id = demand_line_id.presence
      @store = store
    end

    def active?
      from_demand_line? && demand_line_id.present?
    end

    def from_demand_line?
      @return_to == RETURN_TO
    end

    attr_reader :demand_line_id, :store

    def demand_line
      return @demand_line if defined?(@demand_line)

      @demand_line = active? ? DemandLine.find_by(id: demand_line_id, store: store) : nil
    end

    def valid?
      return false unless active?
      return false if demand_line.blank?
      return false if demand_line.terminal?
      return false unless demand_line.status == "captured"

      true
    end

    def matched?
      demand_line&.product_variant_id.present?
    end

    def param_hash
      return {} unless active?

      {
        return_to: RETURN_TO,
        demand_line_id: demand_line_id
      }
    end

    def return_path
      return nil if demand_line.blank?

      Rails.application.routes.url_helpers.demand_demand_line_path(demand_line)
    end

    def banner_label
      return nil unless valid?

      item_label = demand_line.provisional_title.presence || demand_line.provisional_identifier.presence || demand_line.demand_number
      "Matching #{demand_line.demand_number}: #{item_label}"
    end
  end
end
