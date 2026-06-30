# frozen_string_literal: true

module V0042TestHelper
  def ensure_v0042_internal_ean_sequences!
    InternalEanSequence::ACTIVE_V0042_PAIRS.each do |segment, purpose|
      InternalEanSequence.find_or_create_by!(segment: segment) do |row|
        row.purpose = purpose
        row.last_sequence = 0
        row.active = true
      end
    end
  end
end
