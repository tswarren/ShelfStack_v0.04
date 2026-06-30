# frozen_string_literal: true

module Seeds
  module V0042InternalEanSequences
    module_function

    def seed!
      InternalEanSequence::ACTIVE_V0042_PAIRS.each do |segment, purpose|
        InternalEanSequence.find_or_create_by!(segment: segment) do |row|
          row.purpose = purpose
          row.last_sequence = 0
          row.active = true
        end
      end
    end
  end
end
