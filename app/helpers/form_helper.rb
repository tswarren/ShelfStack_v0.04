# frozen_string_literal: true

module FormHelper
  def ss_field_css(record, field)
    base = "ss-field"
    record.errors[field].any? ? "#{base} ss-field--error" : base
  end

  def ss_field_error(record, field)
    return unless record.errors[field].any?

    tag.p(record.errors[field].to_sentence, class: "ss-field-error")
  end

  def ss_required_label(text)
    safe_join([text, tag.abbr("*", title: "required", class: "ss-required")], " ")
  end
end
