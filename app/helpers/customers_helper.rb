# frozen_string_literal: true

module CustomersHelper
  include DemandHelper

  QUEUE_LABELS = {
    "new" => "New",
    "needs_research" => "Needs research",
    "awaiting_response" => "Awaiting response",
    "approved_to_order" => "Approved to order",
    "on_order" => "On order",
    "ready_for_pickup" => "Ready for pickup",
    "notify_customer" => "Notify customer",
    "expiring_holds" => "Expiring holds",
    "completed" => "Completed",
    "cancelled" => "Cancelled",
    "unfillable" => "Unfillable"
  }.freeze

  def customers_status_badge(status)
    css_class = customers_status_badge_class(status)
    tag.span(status.to_s.tr("_", " ").titleize, class: "ss-status-badge #{css_class}")
  end

  def customers_status_badge_class(status)
    case status.to_s
    when "new", "pending_match"
      "status-draft"
    when "researching", "matched", "awaiting_customer_response"
      "status-partial"
    when "approved", "approved_to_order", "ordered", "partially_filled", "partially_received"
      "status-submitted"
    when "ready_for_pickup", "ready"
      "status-submitted"
    when "completed", "fulfilled"
      "status-active"
    when "cancelled", "unfillable", "expired", "released"
      "status-cancelled"
    else
      "status-inactive"
    end
  end

  def customers_queue_label(queue_key)
    QUEUE_LABELS.fetch(queue_key, queue_key.to_s.humanize)
  end

  def customers_queue_link_label(queue_key, counts = nil)
    label = queue_key.nil? ? "All" : customers_queue_label(queue_key)
    return label if counts.blank?

    count = queue_key.nil? ? counts.values.sum : counts.fetch(queue_key.to_s, 0)
    count.positive? ? "#{label} (#{count})" : label
  end

  def customers_queue_active?(queue_key)
    params[:queue].to_s == queue_key.to_s
  end

  def customers_request_type_label(type)
    type.to_s.tr("_", " ").titleize
  end

  def customers_preferred_contact_label(method)
    method.to_s.tr("_", " ").titleize
  end

  def customers_queue_link_class(queue_key)
    base = "ss-btn ss-btn-small"
    active = queue_key.nil? ? params[:queue].blank? : customers_queue_active?(queue_key)
    active ? base : "#{base} ss-btn-secondary"
  end

  def customers_request_match_context
    @customers_request_match_context ||= Customers::RequestMatchContext.from_params(
      params,
      store: current_store
    )
  end

  def customers_request_match_params(context = customers_request_match_context)
    context.valid? ? context.param_hash : {}
  end

  def customers_request_match_path_options(context = customers_request_match_context)
    customers_request_match_params(context)
  end

  def customers_request_match_banner_label(context = customers_request_match_context)
    context.banner_label if context.valid?
  end

  def customers_request_match_link_params(customer_request:, line:, query: nil)
    {
      return_to: Customers::RequestMatchContext::RETURN_TO,
      customer_request_id: customer_request.id,
      line_id: line.id,
      q: query
    }.compact
  end

  def stored_value_account_title(account)
    if account.customer
      account.customer.display_name
    elsif account.holder_name_snapshot.present?
      account.holder_name_snapshot
    else
      "Account ##{account.id}"
    end
  end

  def stored_value_account_type_label(account_type)
    account_type.to_s.tr("_", " ").titleize
  end

  def stored_value_account_status(account)
    tag.span(status_label(account.active?), class: status_class(account.active?))
  end

  def stored_value_revealed_identifier_for(identifier)
    revealed = flash[:stored_value_revealed_identifier]
    return unless revealed.is_a?(Hash)
    return unless revealed["id"].to_i == identifier.id

    revealed["value"]
  end
end
