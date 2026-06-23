# frozen_string_literal: true

module BuybacksHelper
  include SetupFormatHelper

  def buyback_money(cents)
    format_cents(cents)
  end

  def buyback_status_label(status)
    status.to_s.humanize
  end

  def buyback_payout_options
    BuybackSession::PAYOUT_MODES.map { |mode| [mode.humanize, mode] }
  end
end
