# frozen_string_literal: true

module Setup
  class BisacSubjectsController < BaseController
    before_action -> { authorize!("setup.bisac_subjects.view") }, only: :show
    before_action -> { authorize!("setup.bisac_subjects.import") }, only: :import

    def show
      @scheme = CategoryScheme.find_by(scheme_key: Bisac::CategoryNodeImporter::SCHEME_KEY)
      @node_count = @scheme&.category_nodes&.count.to_i
      @source_path = Bisac::CsvReader::DEFAULT_PATH
      @source_mtime = File.exist?(@source_path) ? File.mtime(@source_path) : nil
      @last_import = AuditEvent.where(event_name: "bisac_subjects.imported").order(occurred_at: :desc).first
    end

    def import
      result = Bisac::CategoryNodeImporter.call
      record_audit!(
        "bisac_subjects.imported",
        result.scheme,
        details: {
          "created" => result.created,
          "updated" => result.updated,
          "total" => result.total,
          "source_path" => Bisac::CsvReader::DEFAULT_PATH.to_s
        }
      )
      redirect_to setup_bisac_subjects_path,
                  notice: "BISAC subjects loaded. #{result.created} created, #{result.updated} updated (#{result.total} total nodes)."
    rescue ArgumentError => e
      redirect_to setup_bisac_subjects_path, alert: e.message
    end
  end
end
