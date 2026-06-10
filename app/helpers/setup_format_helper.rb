# frozen_string_literal: true

module SetupFormatHelper
  def format_basis_points(bps)
    return "—" if bps.nil?

    format("%.2f%%", bps / 100.0)
  end

  def normalized_department_number_preview(value)
    return "—" if value.blank?

    stripped = value.to_s.strip
    return stripped unless stripped.match?(/\A\d+\z/)

    numeric = stripped.to_i
    return stripped if numeric.negative? || numeric > 999

    format("%03d", numeric)
  end
end
