# frozen_string_literal: true

module Setup
  class AuditEventsController < BaseController
    before_action -> { authorize!("audit_events.view") }

    def index
      @audit_events = AuditEvent.includes(:actor_user, :store, :workstation).recent_first.limit(200)
      @audit_events = @audit_events.where(event_name: params[:event_name]) if params[:event_name].present?
    end

    def show
      @audit_event = AuditEvent.find(params[:id])
    end
  end
end
