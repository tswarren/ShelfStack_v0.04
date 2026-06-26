# frozen_string_literal: true

module Pos
  class ReportScope
    TYPES = %i[register_session business_date date_range].freeze

    attr_reader :type, :store, :register_session, :business_date, :start_date, :end_date, :label

    def self.from_params(store:, params:)
      filter_type = params[:filter_type].presence

      if filter_type.present?
        case filter_type.to_s
        when "register_session"
          return register_session_scope(store: store, register_session_id: params[:register_session_id])
        when "business_date"
          return business_date_scope(store: store, business_date: params[:business_date])
        when "date_range"
          return date_range_scope(store: store, start_date: params[:start_date], end_date: params[:end_date])
        else
          return nil
        end
      end

      register_session_scope(store: store, register_session_id: params[:register_session_id]) ||
        business_date_scope(store: store, business_date: params[:business_date]) ||
        date_range_scope(store: store, start_date: params[:start_date], end_date: params[:end_date])
    rescue ArgumentError
      nil
    end

    def self.register_session_scope(store:, register_session_id:)
      return nil if register_session_id.blank?

      session = PosRegisterSession.where(store: store).find_by(id: register_session_id)
      return nil if session.blank?

      new(
        type: :register_session,
        store: store,
        register_session: session,
        label: "Register session #{session.workstation.name} · #{session.business_date} · opened #{I18n.l(session.opened_at.in_time_zone(store.time_zone), format: :short)}"
      )
    end

    def self.business_date_scope(store:, business_date:)
      return nil if business_date.blank?

      date = Date.parse(business_date)
      new(
        type: :business_date,
        store: store,
        business_date: date,
        label: "Business date #{I18n.l(date, format: :long)}"
      )
    end

    def self.date_range_scope(store:, start_date:, end_date:)
      return nil if start_date.blank? || end_date.blank?

      start_date = Date.parse(start_date)
      end_date = Date.parse(end_date)
      return nil if end_date < start_date

      new(
        type: :date_range,
        store: store,
        start_date: start_date,
        end_date: end_date,
        label: "#{I18n.l(start_date, format: :long)} – #{I18n.l(end_date, format: :long)}"
      )
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
