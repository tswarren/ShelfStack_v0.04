# frozen_string_literal: true

module Sourcing
  class LockedOutController < ApplicationController
    before_action :require_active_session

    layout "application"

    def show; end
  end
end
