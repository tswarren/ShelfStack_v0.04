# frozen_string_literal: true

require "test_helper"

class ItemsItemPresenterGenreTest < ActiveSupport::TestCase
  test "subject groups prefer linked genre categorizations over legacy free text" do
    scheme = CategoryScheme.find_or_create_by!(scheme_key: "music_genres") do |s|
      s.name = "Music Genres"
      s.purpose = "music_genres"
      s.active = true
    end
    node = CategoryNode.create!(
      category_scheme: scheme,
      node_key: "rock",
      name: "Rock",
      sort_order: 1,
      active: true
    )
    product = create_product!(catalog_item_type: "recorded_music", genres: "Legacy Genre")
    product.categorizations.create!(category_node: node, primary: true, source: "manual")
    presenter = Items::ItemPresenter.from_product(product)

    genre_group = presenter.subject_groups.find { |group| group[:label] == "Genres" }
    assert_equal [ "Rock" ], genre_group[:headings]
    assert_includes presenter.subject_headings, "Rock"
    refute_includes presenter.subject_headings, "Legacy Genre"
  end
end
