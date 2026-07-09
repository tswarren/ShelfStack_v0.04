# frozen_string_literal: true

module Products
  class GenreSync
    Result = Data.define(:linked_count, :warnings, :skipped)

    def self.sync!(record:, scheme_key:, primary_genre_category_node_id: nil, genre_category_node_ids: nil, source: "manual")
      new(
        record: record,
        scheme_key: scheme_key,
        primary_genre_category_node_id: primary_genre_category_node_id,
        genre_category_node_ids: genre_category_node_ids,
        source: source
      ).sync!
    end

    def initialize(record:, scheme_key:, primary_genre_category_node_id: nil, genre_category_node_ids: nil, source: "manual")
      @record = record
      @scheme_key = scheme_key
      @primary_genre_category_node_id = primary_genre_category_node_id.presence
      @genre_category_node_ids = Array(genre_category_node_ids).map(&:presence).compact
      @source = source
      @warnings = []
    end

    def sync!
      scheme = CategoryScheme.active_records.find_by(scheme_key: @scheme_key)
      unless scheme
        return Result.new(
          linked_count: 0,
          warnings: [ "Genre scheme #{@scheme_key} is not loaded." ],
          skipped: true
        )
      end

      node_ids = ([ @primary_genre_category_node_id ] + @genre_category_node_ids).compact.uniq
      if node_ids.empty?
        remove_genre_categorizations!(scheme)
        return Result.new(linked_count: 0, warnings: [], skipped: false)
      end

      nodes = scheme.category_nodes.active_records.where(id: node_ids).includes(:parent).to_a
      primary_node = nodes.find { |node| node.id.to_s == @primary_genre_category_node_id.to_s } || nodes.first
      replace_genre_categorizations!(scheme, nodes, primary_node)

      Result.new(linked_count: genre_categorizations(scheme).count, warnings: @warnings, skipped: false)
    end

    private

    def genre_categorizations(scheme)
      @record.categorizations.joins(:category_node).where(category_nodes: { category_scheme_id: scheme.id })
    end

    def replace_genre_categorizations!(scheme, nodes, primary_node)
      keep_ids = nodes.map(&:id)
      genre_categorizations(scheme).where.not(category_node_id: keep_ids).destroy_all

      nodes.each do |node|
        categorization = @record.categorizations.find_or_initialize_by(category_node: node)
        categorization.assign_attributes(primary: primary_node&.id == node.id, source: @source)
        categorization.save!
      end

      genre_categorizations(scheme).destroy_all if nodes.empty?
    end

    def remove_genre_categorizations!(scheme)
      genre_categorizations(scheme).destroy_all
    end
  end
end
