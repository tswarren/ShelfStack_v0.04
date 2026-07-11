# frozen_string_literal: true

module Shelfstack
  module V00416Verify
    module_function

    SLICE_ORDER = %w[foundation resolvers genre_picker progressive_form add_item variant_form final].freeze
    SPEC_BUNDLE = "docs/v0.04/v0.04-16-product-entry-revamp".freeze
    MVP_FORMAT_MINIMUM = 25

    def slice
      ENV.fetch("V00416_SLICE", "final").downcase
    end

    def slice_index
      SLICE_ORDER.index(slice) || SLICE_ORDER.length - 1
    end

    def at_least?(target_slice)
      SLICE_ORDER.index(target_slice).to_i <= slice_index
    end

    def spec_bundle_exists?
      %w[spec.md data-model.md test-plan.md].all? do |file|
        File.exist?(Rails.root.join(SPEC_BUNDLE, file))
      end
    end

    def completion_stub_exists?
      File.exist?(Rails.root.join("docs/implementation/v0.04-16-completion.md"))
    end

    def formats_have_eligibility_columns?
      Format.column_names.include?("catalog_item_type") &&
        Format.column_names.include?("digital") &&
        Format.column_names.include?("sort_order")
    end

    def mvp_format_count_met?
      Format.where.not(catalog_item_type: nil).count >= MVP_FORMAT_MINIMUM
    end

    def genre_schemes_exist?
      CategoryScheme::GENRE_PURPOSES.all? do |purpose|
        CategoryScheme.active_records.exists?(scheme_key: purpose, purpose: purpose)
      end
    end

    def longest_genre_node_imports?
      scheme = CategoryScheme.find_by(scheme_key: "music_genres")
      return false if scheme.blank?

      longest_key = "alternative_emotional_hardcore_emo_emocore"
      scheme.category_nodes.exists?(node_key: longest_key)
    end

    def store_categories_still_max_30?
      scheme = CategoryScheme.find_by(scheme_key: CategoryNode::STORE_CATEGORIES_SCHEME_KEY)
      return true if scheme.blank?

      node = CategoryNode.new(category_scheme: scheme, node_key: "a" * 31, name: "Too long")
      node.valid?
      node.errors[:node_key].any?
    end

    def resolver_services_exist?
      %w[
        Products::FieldVisibilityResolver Products::FormatEligibility Products::OperationalTypeDeriver
        Products::ItemKindNormalizer Products::FieldLabelResolver Products::EntryContext
        Products::MetadataParamsSanitizer
      ].all? { |name| name.safe_constantize }
    end

    def genre_sync_exists?
      defined?(Products::GenreSync) &&
        File.exist?(Rails.root.join("app/controllers/items/genre_subject_searches_controller.rb"))
    end

    def metadata_form_exists?
      File.exist?(Rails.root.join("app/views/items/shared/product_forms/metadata/_form.html.erb"))
    end

    def sanitizer_drops_hidden_on_new?
      product = Product.new
      entry_context = Products::EntryContext.build(product: product, staff_item_kind: "service", mode: :new)
      result = Products::MetadataParamsSanitizer.sanitize(
        params: { title: "Test", format_id: 1, publisher: "X" },
        entry_context: entry_context,
        mode: :new
      )
      result.key?(:format_id) == false && result[:title] == "Test"
    end

    def checks
      [
        { key: "spec_bundle", pass: spec_bundle_exists?, message: "v0.04-16 spec bundle present" },
        { key: "completion_stub", pass: completion_stub_exists?, message: "v0.04-16 completion stub present" },
        { key: "format_columns", pass: !at_least?("foundation") || formats_have_eligibility_columns?, message: "formats eligibility columns migrated" },
        { key: "mvp_formats", pass: !at_least?("foundation") || mvp_format_count_met?, message: "MVP formats seeded (>= #{MVP_FORMAT_MINIMUM})" },
        { key: "genre_schemes", pass: !at_least?("foundation") || genre_schemes_exist?, message: "genre schemes seeded" },
        { key: "longest_genre_key", pass: !at_least?("foundation") || longest_genre_node_imports?, message: "long genre node_key imports" },
        { key: "store_category_max_30", pass: !at_least?("foundation") || store_categories_still_max_30?, message: "store_categories node_key still max 30" },
        { key: "resolvers", pass: !at_least?("resolvers") || resolver_services_exist?, message: "Products resolver services present" },
        { key: "sanitizer_new", pass: !at_least?("resolvers") || sanitizer_drops_hidden_on_new?, message: "MetadataParamsSanitizer drops hidden keys on :new" },
        { key: "genre_sync", pass: !at_least?("genre_picker") || genre_sync_exists?, message: "genre picker stack present" },
        { key: "metadata_form", pass: !at_least?("progressive_form") || metadata_form_exists?, message: "product metadata form partials present" }
      ]
    end

    def run!
      results = checks
      failures = results.reject { |row| row[:pass] }
      results.each do |row|
        puts("#{row[:pass] ? "OK" : "FAIL"} #{row[:key]}: #{row[:message]}")
      end
      return if failures.empty?

      warn "v0.04-16 verify failed (#{failures.size} check(s))"
      exit(1) if ENV["STRICT"].to_s == "1"
    end
  end
end
