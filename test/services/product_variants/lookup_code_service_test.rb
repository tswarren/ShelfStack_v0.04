# frozen_string_literal: true

require "test_helper"

module ProductVariants
  class LookupCodeServiceTest < ActiveSupport::TestCase
    test "adds and normalizes manual lookup code" do
      variant = create_product_variant!
      actor = create_user!(username: "lookupactor")

      lookup_code = LookupCodeService.add!(
        product_variant: variant,
        code: " cafe-1 ",
        actor: actor
      )

      assert_equal "CAFE-1", lookup_code.normalized_code
      assert AuditEvent.exists?(event_name: "variant_lookup_code.created", auditable: lookup_code)
    end

    test "rejects gtin-length numeric lookup code" do
      variant = create_product_variant!

      assert_raises(LookupCodeService::LookupCodeError) do
        LookupCodeService.add!(product_variant: variant, code: "9780123456789")
      end
    end

    test "resolve returns variant for global code" do
      variant = create_product_variant!
      LookupCodeService.add!(product_variant: variant, code: "PLU-42")

      resolved = LookupCodeService.resolve("PLU-42")
      assert_equal variant, resolved
    end
  end
end
