# frozen_string_literal: true

module Inventory
  class BalanceIntegrityCheck
    Mismatch = Data.define(:store_id, :product_variant_id, :cached_on_hand, :ledger_on_hand, :kind, :expected, :actual)

    def self.call(actor: nil)
      new(actor:).call
    end

    def initialize(actor: nil)
      @actor = actor
    end

    def call
      mismatches = []
      ledger_sums.each do |row|
        balance = InventoryBalance.find_by(store_id: row.store_id, product_variant_id: row.product_variant_id)
        cached = balance&.quantity_on_hand || 0
        ledger = row.total_delta.to_i
        next if cached == ledger

        mismatches << Mismatch.new(
          store_id: row.store_id,
          product_variant_id: row.product_variant_id,
          cached_on_hand: cached,
          ledger_on_hand: ledger,
          kind: "on_hand",
          expected: ledger,
          actual: cached
        )
      end

      InventoryBalance.find_each do |balance|
        next if ledger_sums_map.key?([ balance.store_id, balance.product_variant_id ])

        mismatches << Mismatch.new(
          store_id: balance.store_id,
          product_variant_id: balance.product_variant_id,
          cached_on_hand: balance.quantity_on_hand,
          ledger_on_hand: 0,
          kind: "on_hand",
          expected: 0,
          actual: balance.quantity_on_hand
        )

        check_reserved_and_available!(balance, mismatches)
      end

      InventoryBalance.find_each do |balance|
        next unless ledger_sums_map.key?([ balance.store_id, balance.product_variant_id ])

        check_reserved_and_available!(balance, mismatches)
      end

      if (audit_actor = actor || User.find_by(username: ShelfStack::SYSTEM_USERNAME))
        AuditEvents.record!(
          actor: audit_actor,
          event_name: "inventory.integrity_check",
          details: {
            "mismatch_count" => mismatches.size,
            "passed" => mismatches.empty?
          }
        )
      end

      Result.new(passed: mismatches.empty?, mismatches: mismatches)
    end

    Result = Data.define(:passed, :mismatches)

    private

    attr_reader :actor

    def ledger_sums
      @ledger_sums ||= InventoryLedgerEntry
        .select("store_id, product_variant_id, SUM(quantity_delta) AS total_delta")
        .group(:store_id, :product_variant_id)
        .to_a
    end

    def ledger_sums_map
      @ledger_sums_map ||= ledger_sums.index_by { |row| [ row.store_id, row.product_variant_id ] }
    end

    def check_reserved_and_available!(balance, mismatches)
      v0047_reserved = DemandAllocations::AllocationQuantities.active_on_hand_for(
        store: balance.store,
        variant: balance.product_variant
      )
      expected_reserved = v0047_reserved
      if balance.quantity_reserved != expected_reserved
        mismatches << Mismatch.new(
          store_id: balance.store_id,
          product_variant_id: balance.product_variant_id,
          cached_on_hand: balance.quantity_on_hand,
          ledger_on_hand: expected_reserved,
          kind: "reserved",
          expected: expected_reserved,
          actual: balance.quantity_reserved
        )
      end

      expected_available = balance.quantity_on_hand - balance.quantity_reserved
      return if balance.quantity_available == expected_available

      mismatches << Mismatch.new(
        store_id: balance.store_id,
        product_variant_id: balance.product_variant_id,
        cached_on_hand: balance.quantity_on_hand,
        ledger_on_hand: expected_available,
        kind: "available",
        expected: expected_available,
        actual: balance.quantity_available
      )
    end
  end
end
