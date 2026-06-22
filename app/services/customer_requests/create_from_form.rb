# frozen_string_literal: true

module CustomerRequests
  class CreateFromForm
    class CreateError < StandardError; end

    PERMITTED = %i[
      customer_id source preferred_contact_method needed_by_date notes
      customer_name_snapshot customer_email_snapshot customer_phone_snapshot
      assigned_to_user_id
    ].freeze

    LINE_PERMITTED = %i[
      id line_number request_type requested_quantity provisional_title provisional_creator
      provisional_identifier provisional_format notes status _destroy
    ].freeze

    def self.call!(store:, created_by_user:, params:)
      new(store:, created_by_user:, params:).call!
    end

    def initialize(store:, created_by_user:, params:)
      @store = store
      @created_by_user = created_by_user
      @params = params
    end

    def call!
      request_params = params.require(:customer_request).permit(
        *PERMITTED,
        customer_request_lines_attributes: LINE_PERMITTED
      )

      line_attrs = extract_line_attributes(request_params[:customer_request_lines_attributes])

      Create.call(
        store: store,
        created_by_user: created_by_user,
        attributes: request_params.except(:customer_request_lines_attributes).to_h.symbolize_keys,
        lines: line_attrs
      )
    rescue ActionController::ParameterMissing
      raise CreateError, "Customer request parameters are required"
    end

    private

    attr_reader :store, :created_by_user, :params

    def extract_line_attributes(lines_param)
      return [] if lines_param.blank?

      values = lines_param.respond_to?(:to_unsafe_h) ? lines_param.to_unsafe_h.values : lines_param.values
      values.map { |line| line.to_h.symbolize_keys }
    end
  end
end
