# frozen_string_literal: true

module TokenDigest
  module_function

  def generate
    SecureRandom.urlsafe_base64(32)
  end

  def digest(raw_token)
    Digest::SHA256.hexdigest(raw_token.to_s)
  end
end
