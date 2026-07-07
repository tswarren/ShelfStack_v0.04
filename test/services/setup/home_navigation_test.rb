# frozen_string_literal: true

require "test_helper"
require_relative "../../../db/seeds/phase85_permissions"

class SetupHomeNavigationServiceTest < ActiveSupport::TestCase
  setup do
    Seeds::Phase85Permissions.seed!
    @store = create_store!
    @user = create_user!(username: "setup_nav_user", password: "Password123!")
  end

  test "includes links only when user has matching view permission" do
    grant_permission!(@user, "setup.access")
    grant_permission!(@user, "setup.users.view")
    grant_permission!(@user, "setup.vendors.view")

    sections = Setup::HomeNavigation.sections_for(user: @user, store: @store)
    labels = sections.flat_map { |section| section.links.map(&:label).compact }

    assert_includes labels, "Users"
    assert_includes labels, "Vendors"
    assert_not_includes labels, "Roles"
    assert_not_includes labels, "Departments"
  end

  test "omits sections with no permitted links" do
    grant_permission!(@user, "setup.access")
    grant_permission!(@user, "setup.discount_reasons.view")

    sections = Setup::HomeNavigation.sections_for(user: @user, store: @store)
    titles = sections.map(&:title)

    assert_equal [ "Catalog and Items", "Inventory" ], titles
    assert sections.find { |section| section.title == "Inventory" }.links.one?
  end

  test "external data sources link requires setup access only" do
    grant_permission!(@user, "setup.access")

    sections = Setup::HomeNavigation.sections_for(user: @user, store: @store)
    catalog_links = sections.find { |section| section.title == "Catalog and Items" }&.links || []

    assert catalog_links.any? { |link| link.path.end_with?("/setup/external_data_sources") }
  end

  test "store category nodes path uses store categories scheme when present" do
    grant_permission!(@user, "setup.access")
    grant_permission!(@user, "setup.category_schemes.view")
    scheme = CategoryScheme.find_or_create_by!(scheme_key: CategoryNode::STORE_CATEGORIES_SCHEME_KEY) do |record|
      record.name = "Store Categories"
      record.purpose = CategoryNode::STORE_CATEGORIES_SCHEME_KEY
      record.active = true
    end

    sections = Setup::HomeNavigation.sections_for(user: @user, store: @store)
    store_categories_link = sections.flat_map(&:links).find { |link| link.label == "Store Categories" }

    expected_path = Rails.application.routes.url_helpers.setup_category_scheme_category_nodes_path(scheme)

    assert_equal expected_path, store_categories_link.path
  end
end
