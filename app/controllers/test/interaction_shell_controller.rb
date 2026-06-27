# frozen_string_literal: true

module Test
  class InteractionShellController < ApplicationController
    include Interaction::ToastStreamable

    skip_before_action :enforce_onboarding_requirements

    def show
      @background_version = 0
      render layout: "application"
    end

    def turbo_update
      @background_version = Time.current.to_i

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "fixture-background-panel",
            partial: "test/interaction_shell/background_panel",
            locals: { version: @background_version }
          )
        end
      end
    end

    def append_toast
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: append_toast_stream(
            message: params.fetch(:message, "Fixture toast."),
            variant: params.fetch(:variant, "info").to_sym
          )
        end
      end
    end

    def replace_drawer
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "fixture-drawer",
            "<div id=\"fixture-drawer-replaced\" hidden aria-hidden=\"true\"></div>"
          )
        end
      end
    end
  end
end
