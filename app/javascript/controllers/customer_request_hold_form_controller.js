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

  setAvailability({ available, onHand }) {
    this.availableValue = parseInt(available, 10) || 0
    this.onHandValue = parseInt(onHand, 10) || 0
    this.quantityChanged()
  }

  quantityChanged() {
    if (this.requestType() !== "hold") {
      if (this.hasWarningTarget) this.warningTarget.hidden = true
      if (this.hasOverridePanelTarget) this.overridePanelTarget.hidden = true
      if (this.hasOverrideReasonTarget) this.overrideReasonTarget.required = false
      if (this.hasSubmitTarget) this.submitTarget.disabled = false
      return
    }

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

  requestType() {
    const field = this.element.querySelector("#request_type")
    return field?.value || ""
  }
}
