# frozen_string_literal: true

require "test_helper"

class StoredValue::IdentifierVaultTest < ActiveSupport::TestCase
  test "encrypt and decrypt round trip" do
    plaintext = "1234567890123456"
    ciphertext = StoredValue::IdentifierVault.encrypt!(plaintext)

    assert_not_equal plaintext, ciphertext
    assert_equal plaintext, StoredValue::IdentifierVault.decrypt(ciphertext)
  end
end
