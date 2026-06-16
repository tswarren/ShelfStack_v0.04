# frozen_string_literal: true

module SetupClassificationHelper
  SCHEME_PURPOSE_LABELS = {
    "store_categories" => "Store categories",
    "store_sections_topics" => "Store categories (legacy)",
    "reporting" => "Reporting",
    "website" => "Website",
    "browse" => "Browse",
    "internal" => "Internal",
    "bisac" => "BISAC"
  }.freeze

  def humanize_scheme_purpose(purpose)
    SCHEME_PURPOSE_LABELS.fetch(purpose.to_s, humanize_controlled_value(purpose))
  end

  def setup_store_category_nodes_path
    scheme = CategoryScheme.find_by(scheme_key: CategoryNode::STORE_CATEGORIES_SCHEME_KEY)
    if scheme
      setup_category_scheme_category_nodes_path(scheme)
    else
      setup_category_schemes_path
    end
  end
end
