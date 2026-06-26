# frozen_string_literal: true

module Items
  class IndexWarningSummary
    Summary = Data.define(:worst_severity, :counts_by_severity, :warning_count)

    def self.for(store:, user:, results:, contexts: OperationalWarningBuilder.default_contexts)
      new(store:, user:, results:, contexts:).summaries_by_presenter
    end

    def initialize(store:, user:, results:, contexts:)
      @store = store
      @user = user
      @results = Array(results)
      @contexts = contexts
    end

    def summaries_by_presenter
      return {} if store.blank? || results.empty?

      warnings_by_item = OperationalWarningBuilder.for_items(
        store: store,
        items: results.map(&:presenter),
        user: user,
        contexts: contexts
      )

      warnings_by_item.transform_values do |warnings|
        Summary.new(
          worst_severity: OperationalWarningBuilder.worst_severity(warnings),
          counts_by_severity: OperationalWarningBuilder.counts_by_severity(warnings),
          warning_count: warnings.size
        )
      end
    end

    private

    attr_reader :store, :user, :results, :contexts
  end
end
