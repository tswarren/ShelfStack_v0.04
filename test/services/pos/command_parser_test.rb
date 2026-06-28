# frozen_string_literal: true

require "test_helper"

class Pos::CommandParserTest < ActiveSupport::TestCase
  test "blank input is empty lane" do
    result = Pos::CommandParser.parse("   ")

    assert_equal :empty, result.lane
  end

  test "slash-prefixed input is command lane" do
    result = Pos::CommandParser.parse("/help")

    assert_equal :command, result.lane
    assert_equal "/help", result.input
  end

  test "bare question mark is command lane" do
    result = Pos::CommandParser.parse("?")

    assert_equal :command, result.lane
    assert_equal "?", result.input
  end

  test "slash question mark is command lane" do
    result = Pos::CommandParser.parse("/?")

    assert_equal :command, result.lane
  end

  test "non-slash input is lookup lane" do
    result = Pos::CommandParser.parse("9780143127741")

    assert_equal :lookup, result.lane
    assert_equal "9780143127741", result.input
  end

  test "bare amount stays on lookup lane" do
    result = Pos::CommandParser.parse("20")

    assert_equal :lookup, result.lane
  end
end
