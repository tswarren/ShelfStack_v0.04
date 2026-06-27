# frozen_string_literal: true

module Interaction
  module ToastStreamable
    extend ActiveSupport::Concern

    private

    def append_toast_stream(message:, variant: :info, auto_dismiss_ms: 5000)
      turbo_stream.append(
        "toast_region",
        partial: "shared/interaction/toast",
        locals: {
          message: message,
          variant: variant,
          auto_dismiss_ms: auto_dismiss_ms
        }
      )
    end
  end
end
