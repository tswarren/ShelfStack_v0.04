# frozen_string_literal: true

require "test_helper"

class ExternalCatalogAuthorNameFormatterTest < ActiveSupport::TestCase
  test "inverts multi-word personal names and appends author role" do
    assert_equal "Burke, Caro Claire [author]",
                 ExternalCatalog::AuthorNameFormatter.format("Caro Claire Burke")
    assert_equal "Fitzgerald, F. Scott [author]",
                 ExternalCatalog::AuthorNameFormatter.format("F. Scott Fitzgerald")
  end

  test "leaves single-token names unchanged without role" do
    assert_equal "Cher", ExternalCatalog::AuthorNameFormatter.format("Cher")
    assert_equal "Madonna", ExternalCatalog::AuthorNameFormatter.format("Madonna")
  end

  test "leaves collective names unchanged without role" do
    assert_equal "The Beatles", ExternalCatalog::AuthorNameFormatter.format("The Beatles")
  end

  test "preserves already inverted names and appends author role when missing" do
    assert_equal "Smith, John [author]",
                 ExternalCatalog::AuthorNameFormatter.format("Smith, John")
  end

  test "preserves existing roles without duplicating" do
    assert_equal "Lee, Harper [author;editor]",
                 ExternalCatalog::AuthorNameFormatter.format("Lee, Harper [author;editor]")
    assert_equal "Tolkien, J.R.R. [author]",
                 ExternalCatalog::AuthorNameFormatter.format("Tolkien, J.R.R. [author]")
  end

  test "respects custom default role" do
    assert_equal "Burke, Caro Claire [editor]",
                 ExternalCatalog::AuthorNameFormatter.format("Caro Claire Burke", default_role: "editor")
  end
end
