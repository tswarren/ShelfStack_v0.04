# frozen_string_literal: true

module Items
  class IdentifierPreviewsController < BaseController
    def show
      render json: ProductIdentifierService.validation_preview_for_legacy_type(
        identifier_type: params[:identifier_type],
        value: params[:value]
      )
    end
  end
end
