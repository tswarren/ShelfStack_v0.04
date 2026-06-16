# frozen_string_literal: true

module FormHelper
  include TreeSelectHelper

  def ss_field_css(record, field)
    base = "ss-field"
    record.errors[field].any? ? "#{base} ss-field--error" : base
  end

  def ss_field_error(record, field)
    return unless record.errors[field].any?

    tag.p(record.errors[field].to_sentence, class: "ss-field-error")
  end

  def ss_required_label(text)
    safe_join([ text, tag.abbr("*", title: "required", class: "ss-required") ], " ")
  end

  def tree_collection_select(form, attribute, records, include_blank: false, label_method: :name, html_options: {})
    selected = form.object&.public_send(attribute)
    blank_label = case include_blank
    when String then include_blank
    when true then ""
    end

    form.select(
      attribute,
      options_for_select(tree_select_options(records, label_method: label_method), selected),
      { include_blank: blank_label },
      html_options
    )
  end

  def tree_select_tag(name, records, selected: nil, include_blank: false, label_method: :name, html_options: {})
    blank_label = case include_blank
    when String then include_blank
    when true then ""
    end

    select_tag(
      name,
      options_for_select(tree_select_options(records, label_method: label_method), selected),
      { include_blank: blank_label }.merge(html_options)
    )
  end
end
