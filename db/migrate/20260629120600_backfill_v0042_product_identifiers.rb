# frozen_string_literal: true

class BackfillV0042ProductIdentifiers < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    V0042::BackfillProductIdentifiers.run!
  end

  def down
    say "Backfill is not reversible automatically"
  end
end
