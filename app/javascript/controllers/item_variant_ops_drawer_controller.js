import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "title",
    "frame",
    "placeholder",
    "demandSection",
    "requestTypeField",
    "productVariantField",
    "holdFields",
    "specialOrderNote",
    "notifyNote",
    "submitButton"
  ]

  static values = {
    url: String,
    variantId: String
  }

  prepareOpen(event) {
    const button = event.currentTarget
    const variantId = button.dataset.variantId
    const sku = button.dataset.variantSku || "Variant"
    const name = button.dataset.variantName || ""

    this.variantIdValue = variantId

    if (this.hasTitleTarget) {
      this.titleTarget.textContent = name ? `${sku} — ${name}` : sku
    }

    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("product_variant_id", variantId)
    this.frameTarget.src = url.toString()

    if (this.hasPlaceholderTarget) {
      this.placeholderTarget.hidden = true
    }

    this.hideDemandSection()
  }

  prepareDemandAction(event) {
    const button = event.currentTarget
    const drawerKey = button.dataset.drawerKey
    const variantId = button.dataset.variantId || this.variantIdValue
    const available = button.dataset.available
    const onHand = button.dataset.onHand

    if (this.hasRequestTypeFieldTarget) {
      this.requestTypeFieldTarget.value = drawerKey
    }
    if (this.hasProductVariantFieldTarget) {
      this.productVariantFieldTarget.value = variantId
    }

    if (this.hasHoldFieldsTarget) {
      this.holdFieldsTarget.hidden = drawerKey !== "hold"
      const form = this.demandForm
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

    if (this.hasDemandSectionTarget) {
      this.demandSectionTarget.hidden = false
    }

    this.resetFormDirtyBaseline()
    this.demandSectionTarget?.scrollIntoView({ block: "nearest" })
  }

  resetOnClose(event) {
    if (event.target.id !== "item-variant-ops-drawer") return

    const form = this.demandForm
    if (form) {
      form.reset()
      const holdController = this.application.getControllerForElementAndIdentifier(
        form, "customer-request-hold-form"
      )
      holdController?.quantityChanged()
    }

    if (this.hasHoldFieldsTarget) this.holdFieldsTarget.hidden = true
    if (this.hasSpecialOrderNoteTarget) this.specialOrderNoteTarget.hidden = true
    if (this.hasNotifyNoteTarget) this.notifyNoteTarget.hidden = true
    if (this.hasSubmitButtonTarget) this.submitButtonTarget.value = "Submit"

    this.hideDemandSection()
    this.variantIdValue = ""
    this.frameTarget.removeAttribute("src")
    this.frameTarget.innerHTML = '<p class="ss-muted">Loading…</p>'

    if (this.hasPlaceholderTarget) {
      this.placeholderTarget.hidden = false
    }
    if (this.hasTitleTarget) {
      this.titleTarget.textContent = "Variant operations"
    }

    this.resetFormDirtyBaseline()
  }

  hideDemandSection() {
    if (this.hasDemandSectionTarget) {
      this.demandSectionTarget.hidden = true
    }
  }

  resetFormDirtyBaseline() {
    const form = this.demandForm
    if (!form) return

    form.querySelectorAll("input, textarea, select").forEach((field) => {
      if (field.type === "checkbox" || field.type === "radio") {
        field.defaultChecked = field.checked
      } else if (field.type !== "submit" && field.type !== "button") {
        field.defaultValue = field.value
      }
    })
  }

  get demandForm() {
    if (!this.hasDemandSectionTarget) return null

    return this.demandSectionTarget.querySelector("form")
  }
}
