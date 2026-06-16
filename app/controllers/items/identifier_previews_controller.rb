# frozen_string_literal: true

module Items
  class IdentifierPreviewsController < BaseController
    def show
      render json: CatalogIdentifierService.validation_preview(
        identifier_type: params[:identifier_type],
        value: params[:value]
      )
    end
  end
end
