# frozen_string_literal: true

require "test_helper"

class Bisac::HierarchyTest < ActiveSupport::TestCase
  test "parent_code follows standard BISAC rules" do
    assert_nil Bisac::Hierarchy.parent_code("FIC000000")
    assert_equal "FIC000000", Bisac::Hierarchy.parent_code("FIC009000")
    assert_equal "FIC009000", Bisac::Hierarchy.parent_code("FIC009010")
    assert_equal "CGN004000", Bisac::Hierarchy.parent_code("CGN004010")
  end

  test "depth counts ancestors" do
    assert_equal 0, Bisac::Hierarchy.depth("FIC000000")
    assert_equal 1, Bisac::Hierarchy.depth("FIC009000")
    assert_equal 2, Bisac::Hierarchy.depth("FIC009010")
  end

  test "synthetic_heading uses General convention" do
    heading = Bisac::Hierarchy.synthetic_heading(
      "CGN004000",
      child_heading: "Comics & Graphic Novels / Crime & Mystery"
    )

    assert_equal "Comics & Graphic Novels / General", heading
  end

  test "synthetic_heading uses child heading for deeper middle tiers" do
    heading = Bisac::Hierarchy.synthetic_heading(
      "BUS037000",
      child_heading: "Business & Economics / Careers / Job Hunting"
    )

    assert_equal "Business & Economics / Careers / Job Hunting", heading
  end
end
