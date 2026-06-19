import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "salePanel",
    "returnReceiptDrawer",
    "openRingDrawer",
    "scanQuantity",
    "entryActionField"
  ]

  static values = {
    initialAction: { type: String, default: "sale" }
  }

  connect() {
    this.setAction(this.initialActionValue)
  }

  selectAction(event) {
    event.preventDefault()
    this.setAction(event.currentTarget.dataset.entryAction)
  }

  setAction(action) {
    this.element.querySelectorAll("[data-entry-action]").forEach((button) => {
      const active = button.dataset.entryAction === action
      button.classList.toggle("ss-pos-entry-switch__btn--active", active)
      button.setAttribute("aria-pressed", active ? "true" : "false")
    })

    this.element.querySelectorAll("[data-pos-line-entry-target='entryActionField'], [data-pos-register-workspace-target='entryActionField']").forEach((field) => {
      field.value = action
    })

    if (this.hasSalePanelTarget) {
      this.salePanelTarget.hidden = action === "open_ring"
    }

    if (this.hasReturnReceiptDrawerTarget) {
      this.returnReceiptDrawerTarget.hidden = action !== "return_receipt"
    }

    if (this.hasOpenRingDrawerTarget) {
      this.openRingDrawerTarget.hidden = action !== "open_ring"
    }

    if (this.hasScanQuantityTarget) {
      if (action === "return_no_receipt") {
        this.scanQuantityTarget.value = -1
      } else if (action === "sale") {
        this.scanQuantityTarget.value = 1
      }
    }

    const scanInput = this.element.querySelector("[data-pos-line-entry-target='lookupInput']")
    if (scanInput && action !== "return_receipt" && action !== "open_ring") {
      scanInput.focus()
    }
  }
}
