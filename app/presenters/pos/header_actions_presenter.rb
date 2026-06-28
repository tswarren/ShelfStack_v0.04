# frozen_string_literal: true

module Pos
  class HeaderActionsPresenter
    Action = Data.define(:key, :label, :available, :message, :stimulus_action)

    MENU = [
      { key: :balance, label: "Stored Value Balance Inquiry", command: :balance, stimulus_action: "showBalanceModal" },
      { key: :session, label: "Session", command: :session, stimulus_action: "openSessionDrawer" },
      { key: :cashin, label: "Cash In", command: :cashin, stimulus_action: "openCashIn" },
      { key: :cashout, label: "Cash Out", command: :cashout, stimulus_action: "openCashOut" },
      { key: :close, label: "Close Register", command: :close, stimulus_action: "runCloseRegister" },
      { key: :reports, label: "Reports", command: :reports, stimulus_action: "runReports" },
      { key: :drawer, label: "Drawer", command: :drawer, stimulus_action: "openDrawerQuickAction" }
    ].freeze

    def self.build(user:, store:, register_session:, transaction: nil, context: :root)
      new(user:, store:, register_session:, transaction:, context:).actions
    end

    def initialize(user:, store:, register_session:, transaction: nil, context: :root)
      @user = user
      @store = store
      @register_session = register_session
      @transaction = transaction
      @context = context
    end

    def actions
      MENU.map { |entry| build_action(entry) }
    end

    private

    attr_reader :user, :store, :register_session, :transaction, :context

    def build_action(entry)
      command = CommandRegistry[entry[:command]]
      availability = CommandRegistry.availability(
        command: command,
        context: context,
        user: user,
        store: store,
        register_session: register_session,
        transaction: transaction,
        check_permissions: true
      )

      Action.new(
        key: entry[:key],
        label: entry[:label],
        available: availability.available,
        message: availability.message,
        stimulus_action: entry[:stimulus_action]
      )
    end
  end
end
