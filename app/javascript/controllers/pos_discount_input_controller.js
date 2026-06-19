import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["type", "value"]
  static values = {
    amountLabel: String,
    percentLabel: String
  }

  connect() {
    this.updateMode()
  }

  updateMode() {
    if (!this.hasTypeTarget || !this.hasValueTarget) return

    const isPercent = this.typeTarget.value === "percent"
    this.valueTarget.step = isPercent ? "0.01" : "0.01"
    this.valueTarget.max = isPercent ? "100" : ""
    this.valueTarget.placeholder = isPercent ? "0.00" : "0.00"
    this.valueTarget.setAttribute("aria-label", isPercent ? this.percentLabelValue : this.amountLabelValue)
  }
}
