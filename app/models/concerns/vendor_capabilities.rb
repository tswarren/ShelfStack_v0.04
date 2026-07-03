# frozen_string_literal: true

module VendorCapabilities
  extend ActiveSupport::Concern

  AVAILABILITY_WORKFLOWS = %w[check_before_order order_to_confirm manual_review].freeze
  AVAILABILITY_SOURCES = %w[
    manual ipage stock_check_app data_services_web_service data_services_ftp
    portal email file_import edi_x12 api none
  ].freeze
  ORDER_SUBMISSION_METHODS = %w[manual ipage portal email file_export edi_x12 api].freeze
  ACKNOWLEDGMENT_METHODS = %w[manual portal email file_import edi_x12 api none].freeze
  SHIPMENT_NOTICE_METHODS = %w[manual portal email file_import edi_x12 api none].freeze
  INVOICE_METHODS = %w[manual email paper file_import edi_x12 api none].freeze
  TECHNICAL_ACKNOWLEDGMENT_METHODS = %w[none edi_x12 api].freeze
  FULFILLMENT_METHODS = %w[
    ship_to_store vendor_direct_to_customer consolidated_shipment holding_order
  ].freeze

  DEFAULT_FULFILLMENT_METHODS = ["ship_to_store"].freeze
  WHOLESALER_FULFILLMENT_METHODS = %w[
    ship_to_store vendor_direct_to_customer consolidated_shipment holding_order
  ].freeze

  included do
    validates :availability_workflow, inclusion: { in: AVAILABILITY_WORKFLOWS }
    validates :availability_source, inclusion: { in: AVAILABILITY_SOURCES }
    validates :order_submission_method, inclusion: { in: ORDER_SUBMISSION_METHODS }
    validates :acknowledgment_method, inclusion: { in: ACKNOWLEDGMENT_METHODS }
    validates :shipment_notice_method, inclusion: { in: SHIPMENT_NOTICE_METHODS }
    validates :invoice_method, inclusion: { in: INVOICE_METHODS }
    validates :technical_acknowledgment_method, inclusion: { in: TECHNICAL_ACKNOWLEDGMENT_METHODS }
    validate :fulfillment_methods_supported_values

    before_validation :normalize_fulfillment_methods_supported
  end

  def supports_fulfillment_method?(method)
    Array(fulfillment_methods_supported).include?(method.to_s)
  end

  private

  def normalize_fulfillment_methods_supported
    methods = Array(fulfillment_methods_supported).map(&:to_s).uniq
    self.fulfillment_methods_supported = methods.presence || DEFAULT_FULFILLMENT_METHODS.dup
  end

  def fulfillment_methods_supported_values
    invalid = Array(fulfillment_methods_supported) - FULFILLMENT_METHODS
    return if invalid.empty?

    errors.add(:fulfillment_methods_supported, "contains invalid values: #{invalid.join(', ')}")
  end
end
