# frozen_string_literal: true

class CreatePhase7c1BuybackRefinement < ActiveRecord::Migration[8.0]
  OUTCOME_MAP = {
    "accepted_for_cash" => "accepted_by_customer",
    "accepted_for_trade_credit" => "accepted_by_customer",
    "accepted_as_donation" => "donated_by_customer",
    "rejected_returned_to_seller" => "declined_by_customer",
    "rejected_recycle" => "recycle_with_permission"
  }.freeze

  STATUS_MAP = {
    "accepted" => "decided",
    "rejected" => "decided"
  }.freeze

  def up
    change_table :buyback_lines, bulk: true do |t|
      t.integer :proposed_resale_price_cents
      t.integer :proposed_cash_offer_cents
      t.integer :proposed_trade_credit_offer_cents
      t.integer :base_price_cents
      t.string :base_price_source
      t.datetime :customer_decision_at
      t.boolean :cash_offer_overridden, null: false, default: false
      t.boolean :trade_credit_offer_overridden, null: false, default: false
      t.text :resale_price_override_reason
      t.text :cash_offer_override_reason
      t.text :trade_credit_offer_override_reason
    end

    change_table :buyback_sessions, bulk: true do |t|
      t.datetime :proposal_saved_at
      t.datetime :proposal_printed_at
      t.datetime :customer_decision_at
      t.datetime :payout_selected_at
    end

    migrate_line_data!
    migrate_session_data!
  end

  def down
    revert_line_data!

    change_table :buyback_lines, bulk: true do |t|
      t.remove :proposed_resale_price_cents
      t.remove :proposed_cash_offer_cents
      t.remove :proposed_trade_credit_offer_cents
      t.remove :base_price_cents
      t.remove :base_price_source
      t.remove :customer_decision_at
      t.remove :cash_offer_overridden
      t.remove :trade_credit_offer_overridden
      t.remove :resale_price_override_reason
      t.remove :cash_offer_override_reason
      t.remove :trade_credit_offer_override_reason
    end

    change_table :buyback_sessions, bulk: true do |t|
      t.remove :proposal_saved_at
      t.remove :proposal_printed_at
      t.remove :customer_decision_at
      t.remove :payout_selected_at
    end
  end

  private

  def migrate_line_data!
    say_with_time "Migrating buyback line outcomes, statuses, and proposed fields" do
      BuybackLine.reset_column_information
      BuybackLine.find_each do |line|
        updates = {}

        if line.outcome.present? && OUTCOME_MAP.key?(line.outcome)
          updates[:outcome] = OUTCOME_MAP[line.outcome]
        end

        if STATUS_MAP.key?(line.status)
          updates[:status] = STATUS_MAP[line.status]
        elsif line.status == "priced" && line.product_variant_id.present? && line.product_condition_id.present?
          updates[:status] = "resolved" if line.proposed_resale_price_cents.blank?
        end

        updates[:proposed_resale_price_cents] = line.accepted_resale_price_cents if line.accepted_resale_price_cents.present?
        if line.accepted_offer_cents.present?
          case line.outcome
          when "accepted_for_trade_credit"
            updates[:proposed_trade_credit_offer_cents] = line.accepted_offer_cents
          when "accepted_for_cash", "accepted_as_donation", nil
            updates[:proposed_cash_offer_cents] = line.accepted_offer_cents
          end
        end

        updates[:proposed_cash_offer_cents] ||= line.suggested_cash_offer_cents
        updates[:proposed_trade_credit_offer_cents] ||= line.suggested_trade_credit_offer_cents
        updates[:proposed_resale_price_cents] ||= line.suggested_resale_price_cents

        if line.resale_price_overridden? && line.override_reason.present?
          updates[:resale_price_override_reason] = line.override_reason
        end
        if line.offer_overridden?
          updates[:cash_offer_overridden] = true
          updates[:cash_offer_override_reason] = line.override_reason if line.override_reason.present?
        end

        line.update_columns(updates) if updates.present?
      end
    end
  end

  def migrate_session_data!
    say_with_time "Migrating buyback session timestamps" do
      BuybackSession.reset_column_information
      BuybackSession.where.not(buyback_number: nil).find_each do |session|
        timestamp = session.quoted_at || session.completed_at
        next if timestamp.blank?

        session.update_columns(
          proposal_saved_at: timestamp,
          customer_decision_at: session.completed_at,
          payout_selected_at: session.completed_at
        )
      end
    end
  end

  def revert_line_data!
    reverse_outcome_map = OUTCOME_MAP.invert.merge(
      "accepted_by_customer" => "accepted_for_cash",
      "donated_by_customer" => "accepted_as_donation",
      "declined_by_customer" => "rejected_returned_to_seller",
      "rejected_by_store" => "rejected_returned_to_seller",
      "recycle_with_permission" => "rejected_recycle"
    )

    BuybackLine.find_each do |line|
      updates = {}
      if line.outcome.present? && reverse_outcome_map.key?(line.outcome)
        updates[:outcome] = reverse_outcome_map[line.outcome]
      end
      updates[:status] = "accepted" if line.status == "decided" && line.outcome.to_s.start_with?("accepted")
      if line.status == "decided" && line.outcome.to_s.match?(/rejected|declined|recycle/)
        updates[:status] = "rejected"
      end
      line.update_columns(updates) if updates.present?
    end

    BuybackSession.where(status: "decision").update_all(status: "quoted")
  end
end
