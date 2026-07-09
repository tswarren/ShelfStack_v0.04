# frozen_string_literal: true

module Items
  module ProductGenreSyncable
    extend ActiveSupport::Concern

    private

    def load_genre_form_state_if_needed(product, entry_context:)
      scheme_key = entry_context.controlled_scheme
      return if scheme_key.blank? || scheme_key == Bisac::CategoryNodeImporter::SCHEME_KEY

      @genre_form_state = if genre_structured_input?
                            load_genre_form_state_from_params(scheme_key: scheme_key)
                          elsif product.persisted?
                            load_genre_form_state(product, scheme_key: scheme_key)
                          else
                            empty_genre_form_state(scheme_key: scheme_key)
                          end
    end

    def load_genre_form_state(product, scheme_key:)
      scheme = CategoryScheme.active_records.find_by(scheme_key: scheme_key)
      categorizations = product.categorizations
                               .joins(:category_node)
                               .where(category_nodes: { category_scheme_id: scheme&.id })
                               .includes(category_node: :parent)
      primary = categorizations.find(&:primary?) || categorizations.first

      {
        primary_genre_category_node_id: primary&.category_node_id,
        primary_genre_category_node_label: primary&.category_node&.breadcrumb_label,
        genre_category_node_ids: categorizations.reject { |row| row.id == primary&.id }.map(&:category_node_id),
        genre_scheme_loaded: scheme.present?
      }
    end

    def load_genre_form_state_from_params(scheme_key:)
      scheme = CategoryScheme.active_records.find_by(scheme_key: scheme_key)
      primary_id = params[:primary_genre_category_node_id].presence
      primary_node = scheme&.category_nodes&.find_by(id: primary_id)
      additional_ids = Array(params[:genre_category_node_ids]).map(&:presence).compact

      {
        primary_genre_category_node_id: primary_id,
        primary_genre_category_node_label: primary_node&.breadcrumb_label,
        genre_category_node_ids: additional_ids,
        genre_scheme_loaded: scheme.present?
      }
    end

    def empty_genre_form_state(scheme_key:)
      scheme = CategoryScheme.active_records.find_by(scheme_key: scheme_key)
      {
        primary_genre_category_node_id: nil,
        primary_genre_category_node_label: nil,
        genre_category_node_ids: [],
        genre_scheme_loaded: scheme.present?
      }
    end

    def genre_structured_input?
      params.key?(:primary_genre_category_node_id) || params.key?(:genre_category_node_ids)
    end

    def sync_product_genre!(product, scheme_key:, primary_genre_category_node_id: nil, genre_category_node_ids: nil)
      Products::GenreSync.sync!(
        record: product,
        scheme_key: scheme_key,
        primary_genre_category_node_id: primary_genre_category_node_id,
        genre_category_node_ids: genre_category_node_ids
      )
    end

    def clear_incompatible_classifications!(product, entry_context:)
      scheme = entry_context.controlled_scheme
      if scheme == Bisac::CategoryNodeImporter::SCHEME_KEY
        CategoryScheme.where(purpose: CategoryScheme::GENRE_PURPOSES).find_each do |genre_scheme|
          product.categorizations.joins(:category_node)
                 .where(category_nodes: { category_scheme_id: genre_scheme.id }).destroy_all
        end
      elsif scheme.present?
        product.bisac_categorizations.destroy_all
        CategoryScheme.where(purpose: CategoryScheme::GENRE_PURPOSES)
                      .where.not(scheme_key: scheme)
                      .find_each do |genre_scheme|
          product.categorizations.joins(:category_node)
                 .where(category_nodes: { category_scheme_id: genre_scheme.id }).destroy_all
        end
      end
    end
  end
end
