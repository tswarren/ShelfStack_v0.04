# frozen_string_literal: true

module Pos
  class WorkspaceCommandsController < BaseController
    def route_command
      if requires_line_add_permission? && !line_add_allowed?
        return render json: {
          action: "message",
          payload: {},
          message: "You are not authorized to add items."
        }, status: :forbidden
      end

      result = Pos::RootCommandHandler.call(
        store: pos_store,
        workstation: current_workstation,
        cashier_user: current_user,
        register_session: current_register_session,
        user_session: Current.user_session,
        input: params[:input],
        product_variant_id: params[:product_variant_id]
      )

      case result.status
      when :redirect
        render json: {
          action: "redirect",
          payload: { url: result.redirect_path },
          message: result.alert
        }
      when :json
        render json: result.json
      else
        render json: {
          action: "message",
          payload: {},
          message: "Unable to process command."
        }, status: :unprocessable_entity
      end
    end

    private

    def requires_line_add_permission?
      return true if params[:product_variant_id].present?

      parsed = Pos::CommandParser.parse(params[:input])
      return false if parsed.lane == :empty
      return false if parsed.lane == :command

      true
    end

    def line_add_allowed?
      Authorization.allowed?(user: current_user, permission_key: "pos.lines.add", store: current_store)
    end
  end
end
