# frozen_string_literal: true

module Items
  module ProductMetadataSectionsRefreshable
    extend ActiveSupport::Concern

    private

    def render_product_metadata_sections(product:, mode:)
      @product = product
      apply_metadata_preview_attributes!(@product)
      @entry_context = build_product_entry_context(@product, mode: mode)
      @formats = @entry_context.eligible_formats
      load_bisac_form_state(@product)
      load_genre_form_state_if_needed(@product, entry_context: @entry_context)
      load_store_category_collections

      render partial: "items/shared/product_forms/metadata/sections_turbo_frame",
             locals: product_metadata_sections_locals(mode: mode)
    end

    def product_metadata_sections_locals(mode:)
      genre_state = genre_form_state_for_preview(entry_context: @entry_context)

      {
        record: @product,
        entry_context: @entry_context,
        form_namespace: metadata_sections_form_namespace,
        store_category_nodes: @store_category_nodes,
        primary_bisac_category_node_id: @primary_bisac_category_node_id,
        primary_bisac_category_node_label: @primary_bisac_category_node_label,
        bisac_category_node_ids: @bisac_category_node_ids || [],
        bisac_scheme_loaded: @bisac_scheme_loaded,
        primary_genre_category_node_id: genre_state[:primary_genre_category_node_id],
        primary_genre_category_node_label: genre_state[:primary_genre_category_node_label],
        genre_category_node_ids: genre_state[:genre_category_node_ids] || [],
        genre_scheme_loaded: genre_state[:genre_scheme_loaded] || false
      }
    end

    def apply_metadata_preview_attributes!(product)
      raw = product_metadata_params_hash
      return if raw.blank?

      entry_context = build_product_entry_context(product, mode: product.persisted? ? :edit : :new)
      attrs = Products::MetadataPreviewParams.filter(
        params: raw,
        entry_context: entry_context,
        mode: product.persisted? ? :edit : :new
      )
      product.assign_attributes(attrs)
    end

    def metadata_sections_form_namespace
      if params[:product].present?
        :product
      else
        :catalog_item
      end
    end

    def genre_form_state_for_preview(entry_context:)
      scheme_key = entry_context.controlled_scheme
      return {} if scheme_key.blank? || scheme_key == Bisac::CategoryNodeImporter::SCHEME_KEY

      if genre_structured_input?
        load_genre_form_state_from_params(scheme_key: scheme_key)
      elsif @product.persisted?
        load_genre_form_state(@product, scheme_key: scheme_key)
      else
        empty_genre_form_state(scheme_key: scheme_key)
      end
    end
  end
end
