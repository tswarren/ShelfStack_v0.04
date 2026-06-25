# frozen_string_literal: true

class SessionReturnLocation
  DISALLOWED_PREFIXES = %w[
    /session/unlock
    /session/lock
    /session/status
    /login
    /logout
    /password
    /pin
    /workstation_assignment
  ].freeze

  def self.sanitize(path)
    return nil if path.blank?

    path = path.to_s
    return nil unless path.start_with?("/")
    return nil if path.start_with?("//")
    return nil if DISALLOWED_PREFIXES.any? { |prefix| path == prefix || path.start_with?("#{prefix}/") || path.start_with?("#{prefix}?") }

    path
  end

  def self.redirect_path_for(session)
    sanitize(session&.locked_return_path)
  end
end
