import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "title",
    "variantSummary",
    "requestTypeField",
    "productVariantField",
    "holdFields",
    "specialOrderNote",
    "notifyNote",
    "submitButton"
  ]

  prepareOpen(event) {
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
        const holdController = this.application.getControllerForElementAndIdentifier(
          form, "customer-request-hold-form"
        )
        if (holdController) {
          holdController.setAvailability({ available: available || "0", onHand: onHand || "0" })
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

    this.resetFormDirtyBaseline()
  }

  resetFormDirtyBaseline() {
    const form = this.element.querySelector("form")
    if (!form) return

    form.querySelectorAll("input, textarea, select").forEach((field) => {
      if (field.type === "checkbox" || field.type === "radio") {
        field.defaultChecked = field.checked
      } else if (field.type !== "submit" && field.type !== "button") {
        field.defaultValue = field.value
      }
    })
  }
}
