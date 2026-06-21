# frozen_string_literal: true

module Setup
  class ExternalDataSourcesController < BaseController
    before_action :load_source
    before_action :authorize_configure!, only: :health_check

    def index
      @sources = ExternalDataSource.order(:name)
    end

    def health_check
      result = ExternalCatalog::CheckProviderHealth.call(source: @source, actor: current_user, force: true)
      redirect_to setup_external_data_sources_path,
                  notice: "Health check: #{result.status} — #{result.message}"
    end

    private

    def load_source
      @source = ExternalDataSource.find_by!(source_key: params[:source_key] || "isbndb")
    end

    def authorize_configure!
      return if Authorization.allowed?(user: current_user, permission_key: "items.external_lookup.configure", store: current_store)

      redirect_to setup_external_data_sources_path, alert: "You do not have permission to run health checks."
    end
  end
end
