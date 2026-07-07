# frozen_string_literal: true

module SetupHomeHelper
  def setup_home_link_label(link)
    if link.label_key.present?
      items_user_facing_label(link.label_key)
    else
      link.label
    end
  end
end
