# frozen_string_literal: true

module Pos
  class ReportScope
    TYPES = %i[register_session business_date date_range].freeze

    attr_reader :type, :store, :register_session, :business_date, :start_date, :end_date, :label

    def self.from_params(store:, params:)
      if params[:register_session_id].present?
        session = PosRegisterSession.where(store: store).find_by(id: params[:register_session_id])
        return nil if session.blank?

        new(
          type: :register_session,
          store: store,
          register_session: session,
          label: "Register session #{session.workstation.name} · #{session.business_date} · opened #{I18n.l(session.opened_at.in_time_zone(store.time_zone), format: :short)}"
        )
      elsif params[:business_date].present?
        date = Date.parse(params[:business_date])
        new(
          type: :business_date,
          store: store,
          business_date: date,
          label: "Business date #{I18n.l(date, format: :long)}"
        )
      elsif params[:start_date].present? && params[:end_date].present?
        start_date = Date.parse(params[:start_date])
        end_date = Date.parse(params[:end_date])
        return nil if end_date < start_date

        new(
          type: :date_range,
          store: store,
          start_date: start_date,
          end_date: end_date,
          label: "#{I18n.l(start_date, format: :long)} – #{I18n.l(end_date, format: :long)}"
        )
      end
    rescue ArgumentError
      nil
    end

    def initialize(type:, store:, label:, register_session: nil, business_date: nil, start_date: nil, end_date: nil)
      @type = type
      @store = store
      @register_session = register_session
      @business_date = business_date
      @start_date = start_date
      @end_date = end_date
      @label = label
    end

    def register_session?
      type == :register_session
    end

    def store_time_zone
      store.time_zone
    end

    def local_time(timestamp)
      timestamp.in_time_zone(store_time_zone)
    end

    def transactions
      scope = PosTransaction.completed_records.where(store: store).includes(:pos_transaction_lines, :pos_tenders, :cashier_user)
      apply_bounds(scope)
    end

    def voids
      scope = PosVoid.where(store: store).includes(:pos_transaction, :voided_by_user)
      apply_bounds(scope)
    end

    def register_sessions
      scope = PosRegisterSession.where(store: store)
      case type
      when :register_session
        scope.where(id: register_session.id)
      when :business_date
        scope.where(business_date: business_date)
      when :date_range
        scope.where(business_date: start_date..end_date)
      else
        scope.none
      end
    end

    private

    def apply_bounds(scope)
      case type
      when :register_session
        if scope.klass == PosTransaction
          scope.where(pos_register_session_id: register_session.id)
        else
          scope.where(pos_register_session_id: register_session.id)
        end
      when :business_date
        scope.where(business_date: business_date)
      when :date_range
        scope.where(business_date: start_date..end_date)
      else
        scope.none
      end
    end
  end
end
