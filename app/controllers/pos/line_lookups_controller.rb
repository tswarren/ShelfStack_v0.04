# frozen_string_literal: true

module Pos
  class LineLookupsController < BaseController
    before_action -> { authorize_pos!("pos.lines.add") }

    def show
      result = Pos::LineLookup.call(store: pos_store, query: params[:q], mode: params[:mode].presence || :exact)

      render json: Pos::LineLookupPresenter.as_json(result, store: pos_store)
    end
  end
end
