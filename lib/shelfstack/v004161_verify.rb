# frozen_string_literal: true

module Shelfstack
  module V004161Verify
    module_function

    SLICE_ORDER = %w[form_stability unified_workflow final].freeze
    SPEC_BUNDLE = "docs/v0.04/v0.04-16.1-unified-product-management".freeze

    def slice
      ENV.fetch("V004161_SLICE", "form_stability").downcase
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
      File.exist?(Rails.root.join("docs/implementation/v0.04-16.1-completion.md"))
    end

    def context_endpoint_exists?
      File.exist?(Rails.root.join("app/controllers/items/product_entry_contexts_controller.rb")) &&
        Rails.application.routes.routes.any? { |route| route.path.spec.to_s.include?("product_entry_context") }
    end

    def entry_context_client_payload?
      product = Product.new(catalog_item_type: "book", product_type: "physical", variation_type: "conditional")
      payload = Products::EntryContext.build(product: product, staff_item_kind: "book", mode: :new).to_client_payload
      payload.key?(:field_visibility) &&
        payload.key?(:eligible_formats) &&
        payload.key?(:short_form) &&
        payload[:field_visibility].values.all? { |state| state.key?(:visible) && state.key?(:required) }
    end

    def form_uses_context_not_preview_url?
      form = File.read(Rails.root.join("app/views/items/shared/product_forms/metadata/_form.html.erb"))
      form.include?("product_metadata_form_context_url_value") &&
        form.exclude?("product-metadata-form-preview-url-value") &&
        form.exclude?("catalog-item-form product-metadata-form") &&
        form.exclude?("sections_frame")
    end

    def controller_avoids_full_form_get?
      js = File.read(Rails.root.join("app/javascript/controllers/product_metadata_form_controller.js"))
      js.exclude?("reloadSections") &&
        js.exclude?("frame.src") &&
        js.include?("field_visibility") &&
        js.include?("contextUrl")
    end

    def field_shell_exists?
      File.exist?(Rails.root.join("app/views/items/shared/product_forms/metadata/_field_shell.html.erb"))
    end

    def field_key_registry_consistent?
      defined?(Products::FieldKeyRegistry) && Products::FieldKeyRegistry.consistent?
    end

    def preview_params_service_exists?
      defined?(Products::MetadataPreviewParams)
    end

    def preview_path_uses_allowlist?
      source = File.read(Rails.root.join("app/controllers/concerns/items/product_metadata_sections_refreshable.rb"))
      source.include?("MetadataPreviewParams") &&
        source.exclude?("raw.except(:staff_item_kind, :catalog_item_type)")
    end

    def canonical_picker_inputs_present?
      bisac = File.read(Rails.root.join("app/views/items/catalog_items/_bisac_subjects_picker.html.erb"))
      genre = File.read(Rails.root.join("app/views/items/shared/product_forms/metadata/_genre_picker.html.erb"))
      bisac.include?('data-product-canonical-inputs="bisac_picker"') &&
        genre.include?('data-product-canonical-inputs="genre_scheme_picker"')
    end

    def checks
      [
        { key: "spec_bundle", pass: spec_bundle_exists?, message: "v0.04-16.1 spec bundle present" },
        { key: "completion_stub", pass: completion_stub_exists?, message: "v0.04-16.1 completion stub present" },
        { key: "field_shell", pass: !at_least?("form_stability") || field_shell_exists?, message: "field shell partial present" },
        { key: "context_endpoint", pass: !at_least?("form_stability") || context_endpoint_exists?, message: "product_entry_context route/controller present" },
        { key: "client_payload", pass: !at_least?("form_stability") || entry_context_client_payload?, message: "EntryContext#to_client_payload shape" },
        { key: "stable_form", pass: !at_least?("form_stability") || form_uses_context_not_preview_url?, message: "metadata form embeds context URL (no Turbo Frame preview)" },
        { key: "stable_js", pass: !at_least?("form_stability") || controller_avoids_full_form_get?, message: "product-metadata-form avoids full-form GET reload" },
        { key: "field_key_registry", pass: !at_least?("form_stability") || field_key_registry_consistent?, message: "FieldKeyRegistry maps only known visibility keys" },
        { key: "preview_params", pass: !at_least?("form_stability") || preview_params_service_exists?, message: "MetadataPreviewParams present" },
        { key: "preview_allowlist", pass: !at_least?("form_stability") || preview_path_uses_allowlist?, message: "HTML preview path uses MetadataPreviewParams" },
        { key: "canonical_pickers", pass: !at_least?("form_stability") || canonical_picker_inputs_present?, message: "BISAC/genre canonical inputs marked in stable shell" },
        { key: "default_variant", pass: !at_least?("unified_workflow") || default_variant_service_exists?, message: "CreateDefaultVariant service present" },
        { key: "add_product_entry", pass: !at_least?("unified_workflow") || add_product_skips_catalog_fork?, message: "Add Product starts at item_details without catalog fork" },
        { key: "edit_product_redirect", pass: !at_least?("unified_workflow") || edit_metadata_redirects?, message: "edit_metadata redirects to Edit Product" }
      ]
    end

    def default_variant_service_exists?
      defined?(Products::CreateDefaultVariant)
    end

    def add_product_skips_catalog_fork?
      source = File.read(Rails.root.join("app/controllers/items/add_item_controller.rb"))
      source.include?('redirect_to items_add_item_path(step: "item_details")') &&
        source.include?('"workflow" => "unified"') &&
        File.read(Rails.root.join("app/views/items/add_item/choose_path.html.erb")).exclude?("Catalog-linked item")
    end

    def edit_metadata_redirects?
      source = File.read(Rails.root.join("app/controllers/items/products_controller.rb"))
      source.match?(/def edit_metadata\n\s+redirect_to edit_items_product_path/m)
    end

    def run!
      results = checks
      failures = results.reject { |row| row[:pass] }
      results.each do |row|
        puts("#{row[:pass] ? "OK" : "FAIL"} #{row[:key]}: #{row[:message]}")
      end
      return if failures.empty?

      warn "v0.04-16.1 verify failed (#{failures.size} check(s))"
      exit(1) if ENV["STRICT"].to_s == "1"
    end
  end
end
