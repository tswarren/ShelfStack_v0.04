# frozen_string_literal: true

class CatalogItemBisacSync
  Result = Data.define(:linked_count, :unresolved_entries, :warnings, :skipped)

  def self.sync!(record: nil, catalog_item: nil, product: nil, primary_bisac_category_node_id: nil, bisac_category_node_ids: nil,
                 bisac_subjects: nil, source: "manual", structured: nil)
    resolved_record = record || product || catalog_item
    new(
      record: resolved_record,
      primary_bisac_category_node_id: primary_bisac_category_node_id,
      bisac_category_node_ids: bisac_category_node_ids,
      bisac_subjects: bisac_subjects,
      source: source,
      structured: structured
    ).sync!
  end

  def initialize(record:, primary_bisac_category_node_id: nil, bisac_category_node_ids: nil,
                 bisac_subjects: nil, source: "manual", structured: nil)
    @record = record
    @primary_bisac_category_node_id = primary_bisac_category_node_id.presence
    @bisac_category_node_ids = Array(bisac_category_node_ids).map(&:presence).compact
    @bisac_subjects = bisac_subjects
    @source = source
    @structured = structured
    @warnings = []
    @unresolved_entries = []
  end

  def sync!
    scheme = bisac_scheme
    unless scheme
      return Result.new(
        linked_count: 0,
        unresolved_entries: [],
        warnings: [ "BISAC subject tree is not loaded. Import subjects from Setup → BISAC Subjects." ],
        skipped: true
      )
    end

    if !structured_input? && bisac_subjects.blank?
      return Result.new(
        linked_count: record.bisac_categorizations.count,
        unresolved_entries: [],
        warnings: [],
        skipped: false
      )
    end

    if structured_input?
      node_ids = ([ primary_bisac_category_node_id ] + bisac_category_node_ids).compact.uniq
      if node_ids.any?
        sync_structured!(scheme)
      elsif bisac_subjects.present?
        sync_from_string!(scheme)
      else
        remove_bisac_categorizations!
        update_subject_fields!(linked_nodes: [], extra_entries: [])
      end
    elsif bisac_subjects.present?
      sync_from_string!(scheme)
    else
      remove_bisac_categorizations!
      update_subject_fields!(linked_nodes: [], extra_entries: [])
    end

    Result.new(
      linked_count: record.bisac_categorizations.count,
      unresolved_entries: unresolved_entries,
      warnings: warnings,
      skipped: false
    )
  end

  private

  attr_reader :record, :primary_bisac_category_node_id, :bisac_category_node_ids,
              :bisac_subjects, :source, :structured, :warnings, :unresolved_entries

  def structured_input?
    structured == true
  end

  def bisac_scheme
    CategoryScheme.active_records.find_by(scheme_key: Bisac::CategoryNodeImporter::SCHEME_KEY)
  end

  def sync_structured!(scheme)
    node_ids = ([ primary_bisac_category_node_id ] + bisac_category_node_ids).compact.uniq
    nodes = resolve_nodes!(scheme, node_ids)
    primary_node = nodes.find { |node| node.id.to_s == primary_bisac_category_node_id.to_s } || nodes.first

    replace_bisac_categorizations!(nodes, primary_node)
    update_subject_fields!(linked_nodes: ordered_nodes(nodes, primary_node), extra_entries: [])
  end

  def sync_from_string!(scheme)
    parsed_entries = MetadataParser.parse_subjects(bisac_subjects)
    linked_nodes = []
    extra_entries = []

    parsed_entries.each do |entry|
      node = resolve_entry_node(scheme, entry)
      if node
        linked_nodes << node unless linked_nodes.any? { |existing| existing.id == node.id }
      else
        extra_entries << entry
        unresolved_entries << entry["heading"]
      end
    end

    primary_node = linked_nodes.first
    replace_bisac_categorizations!(linked_nodes, primary_node)
    update_subject_fields!(linked_nodes: linked_nodes, extra_entries: extra_entries)
  end

  def resolve_nodes!(scheme, node_ids)
    return [] if node_ids.empty?

    nodes = scheme.category_nodes.active_records.where(id: node_ids).includes(:parent).to_a
    missing_ids = node_ids.map(&:to_i) - nodes.map(&:id)
    if missing_ids.any?
      warnings << "Some selected BISAC subjects are no longer available."
    end
    nodes
  end

  def resolve_entry_node(scheme, entry)
    code = entry["code"].presence
    if code.present?
      node = scheme.category_nodes.active_records.find_by(node_key: code.downcase)
      return node if node
    end

    heading = normalize_subject_heading(entry["heading"])
    return if heading.blank?

    scheme.category_nodes.active_records.find_by(name: heading) ||
      scheme.category_nodes.active_records.find { |node| normalize_subject_heading(node.name) == heading }
  end

  def replace_bisac_categorizations!(nodes, primary_node)
    keep_ids = nodes.map(&:id)

    record.bisac_categorizations.where.not(category_node_id: keep_ids).destroy_all

    nodes.each do |node|
      categorization = record.categorizations.find_or_initialize_by(category_node: node)
      categorization.assign_attributes(primary: primary_node&.id == node.id, source: source)
      categorization.save!
    end

    remove_bisac_categorizations! if nodes.empty?
  end

  def remove_bisac_categorizations!
    record.bisac_categorizations.destroy_all
  end

  def ordered_nodes(nodes, primary_node)
    return nodes if primary_node.blank?

    [ primary_node ] + nodes.reject { |node| node.id == primary_node.id }
  end

  def update_subject_fields!(linked_nodes:, extra_entries:)
    subject_data = linked_nodes.map { |node| subject_entry_for(node) } + extra_entries
    subject_string = subject_data.map { |entry| subject_string_for(entry) }.join("; ")

    record.update!(
      bisac_subjects: subject_string.presence,
      bisac_subject_data: subject_data.presence
    )
  end

  def subject_entry_for(node)
    {
      "heading" => node.name,
      "scheme" => "bisac",
      "code" => node.node_key.upcase
    }
  end

  def subject_string_for(entry)
    heading = entry["heading"]
    scheme = entry["scheme"]
    code = entry["code"]

    if scheme == "bisac" && code.present?
      "#{heading} [bisac/#{code}]"
    elsif scheme.present? && scheme != "local"
      code.present? ? "#{heading} [#{scheme}/#{code}]" : "#{heading} [#{scheme}]"
    else
      heading
    end
  end

  def normalize_subject_heading(value)
    value.to_s.strip.gsub("|", " / ").gsub(/\s+/, " ")
  end
end
