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
    "usedWantedNote",
    "replenishmentNote",
    "customerFields",
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

    if (this.hasRequestTypeFieldTarget) {
      this.requestTypeFieldTarget.value = drawerKey
    }
    if (this.hasProductVariantFieldTarget) {
      this.productVariantFieldTarget.value = variantId
    }

    const customerRequired = ["hold", "notify", "special_order", "used_wanted"].includes(drawerKey)
    if (this.hasCustomerFieldsTarget) {
      this.customerFieldsTarget.hidden = !customerRequired
    }

    if (this.hasHoldFieldsTarget) {
      this.holdFieldsTarget.hidden = drawerKey !== "hold"
    }

    if (this.hasSpecialOrderNoteTarget) {
      this.specialOrderNoteTarget.hidden = drawerKey !== "special_order"
    }

    if (this.hasNotifyNoteTarget) {
      this.notifyNoteTarget.hidden = drawerKey !== "notify"
    }

    if (this.hasUsedWantedNoteTarget) {
      this.usedWantedNoteTarget.hidden = drawerKey !== "used_wanted"
    }

    if (this.hasReplenishmentNoteTarget) {
      this.replenishmentNoteTarget.hidden = !["manual_tbo", "buyer_replenishment"].includes(drawerKey)
    }

    if (this.hasSubmitButtonTarget) {
      const labels = {
        hold: "Record hold request",
        special_order: "Record special order",
        notify: "Record notify request",
        used_wanted: "Record used wanted",
        manual_tbo: "Record manual TBO",
        buyer_replenishment: "Record buyer demand"
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

    this.resetDemandForm()
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

  resetDemandForm() {
    const form = this.demandForm
    if (form) {
      form.reset()
    }

    if (this.hasHoldFieldsTarget) this.holdFieldsTarget.hidden = true
    if (this.hasSpecialOrderNoteTarget) this.specialOrderNoteTarget.hidden = true
    if (this.hasNotifyNoteTarget) this.notifyNoteTarget.hidden = true
    if (this.hasUsedWantedNoteTarget) this.usedWantedNoteTarget.hidden = true
    if (this.hasReplenishmentNoteTarget) this.replenishmentNoteTarget.hidden = true
    if (this.hasCustomerFieldsTarget) this.customerFieldsTarget.hidden = false
    if (this.hasSubmitButtonTarget) this.submitButtonTarget.value = "Submit"

    this.hideDemandSection()
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
