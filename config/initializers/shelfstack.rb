# frozen_string_literal: true

module ShelfStack
  SESSION_COOKIE_NAME = "shelfstack_session_token"
  WORKSTATION_COOKIE_NAME = "shelfstack_workstation_token"
  LOGIN_LOCKOUT_THRESHOLD = 5
  SESSION_INACTIVITY_TIMEOUT = 30.minutes
  SUPER_ADMINISTRATOR_ROLE_KEY = "super_administrator"
  SYSTEM_USERNAME = "system"
end
