import { Controller } from "@hotwired/stimulus"

const BLOCKING_PANEL_TARGETS = [
  "giftCardPanel",
  "openRingPanel",
  "sessionPanel",
  "transactionDiscountPanel",
  "cashMovementModal",
  "helpModal",
  "drawerActionModal",
  "balancePanel",
  "receiptPanel",
  "pickupPanel"
]

export default class extends Controller {
  connect() {
    document.dispatchEvent(new CustomEvent("pos:workspace-updated"))

    requestAnimationFrame(() => {
      if (this.constructor.shouldSkipCommandFocus()) return

      document.querySelector("[data-pos-command-bar-target='input']")?.focus()
    })
  }

  static shouldSkipCommandFocus() {
    return BLOCKING_PANEL_TARGETS.some((target) => {
      const element = document.querySelector(`[data-pos-command-bar-target="${target}"]`)
      if (!element) return false

      if (element.tagName === "DETAILS") return element.open

      return !element.hidden
    })
  }
}
