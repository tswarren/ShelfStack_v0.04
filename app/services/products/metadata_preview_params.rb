# frozen_string_literal: true

module Products
  # Allowlisted attributes for temporary HTML preview/context paths.
  # Prefer EntryContext JSON; do not assign raw request params onto products.
  class MetadataPreviewParams
    NON_ASSIGNABLE = (
      %i[staff_item_kind _classification_cleanup] + FieldKeyRegistry::PICKER_PARAM_KEYS
    ).freeze

    def self.filter(params:, entry_context:, mode: :new)
      MetadataParamsSanitizer.sanitize(
        params: params,
        entry_context: entry_context,
        mode: mode
      ).except(*NON_ASSIGNABLE)
    end
  end
end
