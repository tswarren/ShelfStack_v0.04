# frozen_string_literal: true

class InternalEanAllocator
  class AllocationError < StandardError; end

  SEGMENT_RANGE = (200..229)

  def self.allocate!(segment:, purpose:)
    raise AllocationError, "Segment must be a 3-digit string" unless segment.to_s.match?(/\A[0-9]{3}\z/)
    raise AllocationError, "Segment outside 200-229 range" unless SEGMENT_RANGE.cover?(segment.to_i)

    InternalEanSequence.transaction do
      row = InternalEanSequence.lock.find_by(segment: segment, purpose: purpose, active: true)
      raise AllocationError, "Inactive segment/purpose pair" if row.blank?

      expected = InternalEanSequence::ACTIVE_V0042_PAIRS[segment]
      raise AllocationError, "Inactive segment/purpose pair" unless expected == purpose

      next_sequence = row.last_sequence + 1
      if next_sequence > 999_999_999
        raise AllocationError, "Sequence exhausted for segment #{segment}"
      end

      row.update!(last_sequence: next_sequence)
      build_ean13(segment, next_sequence)
    end
  end

  def self.build_ean13(segment, sequence)
    body = format("%s%09d", segment, sequence)
    "#{body}#{check_digit(body)}"
  end

  def self.check_digit(body)
    sum = 0
    body.chars.reverse.each_with_index do |char, index|
      weight = index.even? ? 3 : 1
      sum += char.to_i * weight
    end
    (10 - (sum % 10)) % 10
  end
  private_class_method :check_digit
end
