import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "backdrop",
    "panel",
    "title",
    "variantSummary",
    "requestTypeField",
    "productVariantField",
    "holdFields",
    "specialOrderNote",
    "notifyNote",
    "submitButton"
  ]

  connect() {
    this.element.addEventListener("keydown", this.handleKeydown)
  }

  disconnect() {
    this.element.removeEventListener("keydown", this.handleKeydown)
  }

  handleKeydown = (event) => {
    if (event.key === "Escape" && !this.panelTarget.hidden) {
      this.close()
    }
  }

  open(event) {
    const button = event.currentTarget
    const drawerKey = button.dataset.drawerKey
    const sku = button.dataset.variantSku
    const name = button.dataset.variantName
    const variantId = button.dataset.variantId
    const available = button.dataset.available
    const onHand = button.dataset.onHand

    this.requestTypeFieldTarget.value = drawerKey
    this.productVariantFieldTarget.value = variantId
    this.titleTarget.textContent = button.dataset.actionLabel || "Customer demand"
    this.variantSummaryTarget.textContent = `${sku} — ${name}`

    if (this.hasHoldFieldsTarget) {
      this.holdFieldsTarget.hidden = drawerKey !== "hold"
      const form = this.element.querySelector("form")
      if (form) {
        form.dataset.customerRequestHoldFormAvailableValue = available || "0"
        form.dataset.customerRequestHoldFormOnHandValue = onHand || "0"
        const quantityInput = form.querySelector("[data-customer-request-hold-form-target='quantity']")
        if (quantityInput) {
          quantityInput.dispatchEvent(new Event("change", { bubbles: true }))
        }
      }
    }

    if (this.hasSpecialOrderNoteTarget) {
      this.specialOrderNoteTarget.hidden = drawerKey !== "special_order"
    }

    if (this.hasNotifyNoteTarget) {
      this.notifyNoteTarget.hidden = drawerKey !== "notify"
    }

    if (this.hasSubmitButtonTarget) {
      const labels = {
        hold: "Create hold",
        special_order: "Create special order",
        notify: "Create notify request"
      }
      this.submitButtonTarget.value = labels[drawerKey] || "Submit"
    }

    this.backdropTarget.hidden = false
    this.panelTarget.hidden = false
    document.body.classList.add("ss-drawer-open")
  }

  close() {
    this.backdropTarget.hidden = true
    this.panelTarget.hidden = true
    document.body.classList.remove("ss-drawer-open")
  }
}
