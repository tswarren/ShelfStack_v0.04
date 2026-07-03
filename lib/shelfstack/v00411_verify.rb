# frozen_string_literal: true

module Shelfstack
  module V00411Verify
    module_function

    DROPPED_ORDERING_TABLES = Shelfstack::V00410Verify::LEGACY_TABLES.freeze

    DROPPED_MODEL_PATTERNS = [
      /\bCustomerRequest\b/,
      /\bCustomerRequestLine\b/,
      /\bSpecialOrder\b/,
      /\bPurchaseRequest\b/,
      /\bPurchaseRequestLine\b/,
      /\bInventoryReservation\b/
    ].freeze

    CANONICAL_GUIDANCE_GLOBS = [
      "AGENTS.md",
      "README.md",
      "docs/README.md",
      "docs/overview.md",
      "docs/domain-model.md",
      "docs/glossary.md",
      "docs/schema-reference.md",
      "docs/architecture.md",
      "docs/testing.md"
    ].freeze

    ACTIVE_DOC_GLOBS = [
      *CANONICAL_GUIDANCE_GLOBS,
      "docs/implementation/v0.04-*-completion.md",
      "docs/v0.04/README.md"
    ].freeze

    EXCLUDED_DOC_GLOBS = [
      "docs/specifications/phase-*",
      "docs/roadmap/phase-*",
      "docs/implementation/phase-*-completion.md"
    ].freeze

    PROSE_ALLOWLIST_PATTERNS = [
      /Retired/i,
      /Historical/i,
      /v0\.03 implementation reference/i,
      /Archived/i,
      /Migration history/i,
      /Already-removed/i,
      /already removed/i,
      /Retained temporary/i,
      /legacy admin/i,
      /deprecated compatibility/i,
      /from_tbo \(deprecated\)/i,
      /customers_customer_requests \(redirect\)/i,
      /orders_purchase_requests \(redirect\)/i,
      /do not reintroduce/i,
      /v0\.04-10/i
    ].freeze

    CATALOG_CANONICAL_PATTERNS = [
      /\bcatalog_items\b/,
      /\bcatalog_item_id\b/,
      /\bCatalogItem\b/
    ].freeze

    REDIRECT_ALIAS_NAMES = %w[
      customers_customer_requests
      orders_purchase_requests
    ].freeze

    V004_DOMAIN_TERMS = [
      /demand_lines/,
      /demand_allocations/,
      /DemandLine/,
      /DemandAllocation/,
      /ProductVariant.*operational|operational grain/i
    ].freeze

    def canonical_guidance_files
      CANONICAL_GUIDANCE_GLOBS.flat_map { |glob| Dir.glob(Rails.root.join(glob)) }.uniq.sort
    end

    def active_doc_files
      ACTIVE_DOC_GLOBS.flat_map { |glob| Dir.glob(Rails.root.join(glob)) }.uniq.sort
    end

    def survey_or_pattern_line?(line)
      line.match?(/`\w+`.*\/.*`\w+`/) || line.match?(/\| Pattern \| Files/)
    end

    def schema_reference_in_retired_section?(lines, index)
      lines[0...index].reverse_each do |prior|
        return true if prior.match?(/^# Retired v0\.03 Ordering Tables/)
        return false if prior.match?(/^# /)
      end
      false
    end

    def app_ruby_files
      Dir.glob(Rails.root.join("app/**/*.{rb,erb}")).sort
    end

    def line_allowlisted?(line)
      PROSE_ALLOWLIST_PATTERNS.any? { |pattern| line.match?(pattern) }
    end

    def catalog_canonical_violation?(line)
      return false unless CATALOG_CANONICAL_PATTERNS.any? { |pattern| line.match?(pattern) }

      !line.match?(
        /retain-temporary|Retained temporary|\blegacy\b|legacy admin|legacy bibliographic|Retired|retired|being retired|older vocabulary|not the canonical|do not reintroduce|v0\.04-3|v0\.04-1|table drop|quarantined|superseded|Do not extend/i
      )
    end

    def forbidden_doc_hits
      hits = []
      canonical_guidance_files.each do |path|
        rel = path.sub("#{Rails.root}/", "")
        lines = File.readlines(path, chomp: true)
        lines.each_with_index do |line, index|
          next if line_allowlisted?(line)
          next if survey_or_pattern_line?(line)
          next if rel == "docs/schema-reference.md" && schema_reference_in_retired_section?(lines, index)

          DROPPED_MODEL_PATTERNS.each do |pattern|
            hits << "#{rel}:#{index + 1}:#{pattern.source}" if line.match?(pattern)
          end

          next unless %w[docs/domain-model.md docs/overview.md AGENTS.md README.md].include?(rel)

          CATALOG_CANONICAL_PATTERNS.each do |pattern|
            next unless line.match?(pattern)

            hits << "#{rel}:#{index + 1}:canonical_#{pattern.source}" if catalog_canonical_violation?(line)
          end
        end
      end
      hits.uniq
    end

    def app_dropped_model_hits
      hits = []
      app_ruby_files.each do |path|
        rel = path.sub("#{Rails.root}/", "")
        content = File.read(path)
        DROPPED_MODEL_PATTERNS.each do |pattern|
          next unless content.match?(pattern)

          content.each_line.with_index(1) do |line, line_number|
            next unless line.match?(pattern)
            next if line_allowlisted?(line)

            hits << "#{rel}:#{line_number}:#{pattern.source}"
          end
        end
      end
      hits.uniq
    end

    def v00410_completion_marked_complete?
      path = Rails.root.join("docs/implementation/v0.04-10-completion.md")
      return false unless path.exist?

      content = File.read(path)
      content.match?(/\*\*Complete\*\*/) || content.match?(/Status.*Complete/i)
    end

    def domain_model_describes_v004_chain?
      path = Rails.root.join("docs/domain-model.md")
      return false unless path.exist?

      content = File.read(path)
      V004_DOMAIN_TERMS.count { |pattern| content.match?(pattern) } >= 3
    end

    def glossary_has_retired_section?
      path = Rails.root.join("docs/glossary.md")
      return false unless path.exist?

      content = File.read(path)
      content.match?(/Retired terms/i) && content.match?(/DemandLine|demand line/i)
    end

    def agents_md_references_v004_verifiers?
      path = Rails.root.join("AGENTS.md")
      return false unless path.exist?

      content = File.read(path)
      content.include?("v00411") || content.include?("v00411:verify_documentation_schema_cleanup")
    end

    def v004_milestone_statuses_aligned?
      path = Rails.root.join("docs/v0.04/README.md")
      return false unless path.exist?

      content = File.read(path)
      content.match?(/v0\.04-10.*Complete/i) &&
        (content.match?(/v0\.04-11.*Next/i) || content.match?(/v0\.04-11.*In progress/i) || content.match?(/v0\.04-11.*Complete/i))
    end

    def redirect_aliases_allowlisted?
      routes = File.read(Rails.root.join("config/routes.rb"))
      REDIRECT_ALIAS_NAMES.all? { |name| routes.include?(name) }
    end

    def schema_reference_marks_catalog_retained?
      path = Rails.root.join("docs/schema-reference.md")
      return false unless path.exist?

      content = File.read(path)
      content.match?(/Retained temporary/i) && content.match?(/catalog_items/)
    end

    def checks
      {
        v00410_completion_marked_complete: v00410_completion_marked_complete?,
        active_docs_no_forbidden_legacy_models: forbidden_doc_hits.empty?,
        schema_reference_no_dropped_ordering_tables: schema_reference_dropped_table_hits.empty?,
        domain_model_describes_v004_chain: domain_model_describes_v004_chain?,
        glossary_has_retired_section: glossary_has_retired_section?,
        agents_md_references_v004_verifiers: agents_md_references_v004_verifiers?,
        v004_milestone_statuses_aligned: v004_milestone_statuses_aligned?,
        redirect_aliases_allowlisted: redirect_aliases_allowlisted?,
        schema_reference_marks_catalog_retained: schema_reference_marks_catalog_retained?,
        app_no_dropped_ordering_model_constants: app_dropped_model_hits.empty?
      }
    end

    def schema_reference_dropped_table_hits
      path = Rails.root.join("docs/schema-reference.md")
      return [] unless path.exist?

      hits = []
      lines = File.readlines(path, chomp: true)
      lines.each_with_index do |line, index|
        next if line_allowlisted?(line)
        next if schema_reference_in_retired_section?(lines, index)

        DROPPED_ORDERING_TABLES.each do |table|
          hits << "docs/schema-reference.md:#{index + 1}:#{table}" if line.match?(/\b#{Regexp.escape(table)}\b/)
        end
      end
      hits
    end

    def report(strict: false)
      check_results = checks
      failures = check_results.reject { |_key, ok| ok }.keys
      details = {
        forbidden_doc_hits: forbidden_doc_hits.first(20),
        schema_reference_dropped_table_hits: schema_reference_dropped_table_hits.first(20),
        app_dropped_model_hits: app_dropped_model_hits.first(20)
      }
      status = failures.empty? ? "PASS" : (strict ? "FAIL" : "WARN")

      {
        status: status,
        checks: check_results,
        failures: failures,
        details: details,
        summary: "v0.04-11 documentation/schema cleanup verification: #{status} (#{failures.size} failures)"
      }
    end
  end
end
