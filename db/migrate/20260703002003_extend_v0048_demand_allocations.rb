# frozen_string_literal: true

class ExtendV0048DemandAllocations < ActiveRecord::Migration[8.0]
  def change
    add_reference :demand_allocations, :sourcing_attempt, foreign_key: true
    add_reference :demand_allocations, :vendor_response, foreign_key: true
  end
end
