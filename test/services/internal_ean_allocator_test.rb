# frozen_string_literal: true

require "test_helper"

class InternalEanAllocatorTest < ActiveSupport::TestCase
  test "generates valid 13-digit ean for product house segment" do
    code = InternalEanAllocator.allocate!(segment: "201", purpose: "product_house")

    assert_match(/\A201[0-9]{9}[0-9]\z/, code)
    assert_equal InternalEanAllocator.build_ean13(code[0, 3], code[3, 9].to_i), code
  end

  test "generates valid 13-digit ean for variant sku segment" do
    code = InternalEanAllocator.allocate!(segment: "211", purpose: "variant_sku")

    assert_match(/\A211[0-9]{9}[0-9]\z/, code)
  end

  test "rejects inactive segment purpose pair" do
    assert_raises(InternalEanAllocator::AllocationError) do
      InternalEanAllocator.allocate!(segment: "201", purpose: "variant_sku")
    end
  end

  test "increments sequence per segment" do
    first = InternalEanAllocator.allocate!(segment: "201", purpose: "product_house")
    second = InternalEanAllocator.allocate!(segment: "201", purpose: "product_house")

    assert_not_equal first, second
    assert_equal first[0, 12].to_i + 1, second[0, 12].to_i
  end
end
