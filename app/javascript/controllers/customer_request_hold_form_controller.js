import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "quantity", "overridePanel", "overrideReason", "warning", "submit" ]
  static values = {
    available: Number,
    onHand: Number,
    canOverride: Boolean
  }

  connect() {
    this.quantityChanged()
  }

  quantityChanged() {
    const quantity = parseInt(this.quantityTarget.value, 10) || 0
    const overReserve = quantity > this.availableValue

    if (overReserve) {
      this.warningTarget.textContent =
        `Only ${this.availableValue} ${this.availableValue === 1 ? "copy is" : "copies are"} available. Holding ${quantity} will over-reserve this item.`
      this.warningTarget.hidden = false
    } else {
      this.warningTarget.hidden = true
    }

    if (this.hasOverridePanelTarget) {
      this.overridePanelTarget.hidden = !(overReserve && this.canOverrideValue)
      if (this.hasOverrideReasonTarget) {
        this.overrideReasonTarget.required = overReserve && this.canOverrideValue
      }
    }

    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = overReserve && !this.canOverrideValue
    }
  }
}
