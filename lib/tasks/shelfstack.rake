# frozen_string_literal: true

namespace :shelfstack do
  namespace :password do
    desc "Reset a user's password outside the web UI. " \
         "USERNAME=admin PASSWORD=optional FORCE_PASSWORD_CHANGE=true UNLOCK=true"
    task reset: :environment do
      username = ENV["USERNAME"].to_s.strip
      password = ENV["PASSWORD"].presence
      force_password_change = !%w[0 false no].include?(ENV.fetch("FORCE_PASSWORD_CHANGE", "true").to_s.downcase)
      unlock_account = !%w[0 false no].include?(ENV.fetch("UNLOCK", "true").to_s.downcase)

      if username.blank?
        abort "USERNAME is required. Example: bin/rails shelfstack:password:reset USERNAME=admin"
      end

      result = UserPasswordReset.call(
        username: username,
        password: password,
        force_password_change: force_password_change,
        unlock_account: unlock_account
      )

      puts "Password reset for #{result.user.username}."
      puts "Force password change on next login: #{force_password_change ? 'yes' : 'no'}"
      puts "Account unlocked: #{unlock_account ? 'yes' : 'no'}"

      if result.generated_password
        puts "Generated password: #{result.generated_password}"
        puts "Save this password now. It will not be shown again."
      end
    rescue UserPasswordReset::Error => e
      abort e.message
    end
  end
end
