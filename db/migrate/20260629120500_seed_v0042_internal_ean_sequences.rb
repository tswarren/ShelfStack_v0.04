# frozen_string_literal: true

class SeedV0042InternalEanSequences < ActiveRecord::Migration[8.0]
  def up
    [
      { segment: "201", purpose: "product_house" },
      { segment: "211", purpose: "variant_sku" }
    ].each do |attrs|
      InternalEanSequence.find_or_create_by!(segment: attrs[:segment]) do |row|
        row.purpose = attrs[:purpose]
        row.last_sequence = 0
        row.active = true
      end
    end
  end

  def down
    InternalEanSequence.where(segment: %w[201 211]).delete_all
  end
end
