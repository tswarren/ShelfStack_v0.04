# frozen_string_literal: true

module Interaction
  module ModalStreamable
    extend ActiveSupport::Concern
    include ToastStreamable

    private

    def modal_success_streams(section_target:, section_partial:, section_locals:, message:, modal_id:)
      [
        turbo_stream.replace(section_target, partial: section_partial, locals: section_locals),
        append_toast_stream(message: message, variant: :success),
        close_modal_stream(modal_id: modal_id)
      ]
    end

    def modal_error_streams(body_target:, body_partial:, body_locals:, status: :unprocessable_entity)
      render turbo_stream: turbo_stream.replace(body_target, partial: body_partial, locals: body_locals),
             status: status
    end

    def close_modal_stream(modal_id:)
      turbo_stream.append(
        "modal_close_triggers",
        partial: "shared/interaction/modal_close_trigger",
        locals: { modal_id: modal_id }
      )
    end
  end
end
