# frozen_string_literal: true

module StoredValue
  class IdentifierVault
    def self.encrypt!(plaintext)
      encryptor.encrypt_and_sign(IdentifierCodec.normalize(plaintext))
    end

    def self.decrypt(ciphertext)
      return nil if ciphertext.blank?

      encryptor.decrypt_and_verify(ciphertext)
    rescue ActiveSupport::MessageEncryptor::InvalidMessage
      nil
    end

    def self.encryptor
      @encryptor ||= ActiveSupport::MessageEncryptor.new(
        Rails.application.key_generator.generate_key("stored_value_identifier", ActiveSupport::MessageEncryptor.key_len)
      )
    end
    private_class_method :encryptor
  end
end
