# frozen_string_literal: true

require "test_helper"

class InternalEanSequenceTest < ActiveSupport::TestCase
  test "validates active v0.04-2 segment purpose pairs" do
    sequence = InternalEanSequence.new(segment: "201", purpose: "variant_sku", last_sequence: 0)

    assert_not sequence.valid?
    assert_includes sequence.errors[:purpose], "must be product_house for segment 201"
  end

  test "accepts product_house segment 201" do
    sequence = InternalEanSequence.find_or_initialize_by(segment: "201")
    sequence.assign_attributes(purpose: "product_house", last_sequence: 0, active: true)

    assert sequence.valid?
  end
end
