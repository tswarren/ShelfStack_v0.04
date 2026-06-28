import { Controller } from "@hotwired/stimulus"
import { isAnyOverlayOpen } from "shelfstack/overlay_shell"

const BLOCKING_PANEL_TARGETS = [
  "openRingPanel",
  "transactionDiscountPanel",
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
    if (isAnyOverlayOpen()) return true

    if (document.querySelector(".ss-expand-row--active:not([hidden])")) return true

    const settlementModal = document.getElementById("pos_settlement_modal")
    if (settlementModal && !settlementModal.hidden) return true

    return BLOCKING_PANEL_TARGETS.some((target) => {
      const element = document.querySelector(`[data-pos-command-bar-target="${target}"]`)
      if (!element) return false

      if (element.tagName === "DETAILS") return element.open

      return !element.hidden
    })
  }
}
