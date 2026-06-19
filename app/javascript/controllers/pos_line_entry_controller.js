import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "lookupInput",
    "choices",
    "message",
    "preview",
    "variantId",
    "quantity",
    "unitPrice",
    "form"
  ]

  static values = {
    url: String,
    addUrl: String,
    mode: { type: String, default: "sale" }
  }

  lookupExact(event) {
    if (event.type === "keydown" && event.key !== "Enter") return
    if (event.type === "keydown") event.preventDefault()

    const query = this.lookupInputTarget.value.trim()
    if (!query) {
      this.showMessage("Enter a SKU or barcode.")
      return
    }

    this.fetchLookup({ q: query, mode: "exact" })
  }

  search() {
    const query = this.lookupInputTarget.value.trim()
    if (query.length < 2) {
      this.clearChoices()
      return
    }

    this.fetchLookup({ q: query, mode: "search" })
  }

  fetchLookup(params) {
    const lookupUrl = new URL(this.urlValue, window.location.origin)
    Object.entries(params).forEach(([key, value]) => lookupUrl.searchParams.set(key, value))

    fetch(lookupUrl)
      .then((response) => response.json())
      .then((data) => this.renderResult(data))
      .catch(() => this.showMessage("Unable to look up item right now."))
  }

  renderResult(data) {
    if (data.status === "found") {
      this.selectVariant(data.variants[0])
      return
    }

    if (data.status === "ambiguous" || data.status === "search") {
      this.renderChoices(data.variants)
      this.showMessage(data.message || "")
      return
    }

    this.clearChoices()
    this.showMessage(data.message || "No matching SKU found.")
  }

  renderChoices(variants) {
    this.choicesTarget.innerHTML = ""
    variants.forEach((variant) => {
      const button = document.createElement("button")
      button.type = "button"
      button.className = "ss-btn ss-btn-secondary ss-pos-choice"
      button.textContent = this.variantLabel(variant)
      button.addEventListener("click", () => this.selectVariant(variant))
      this.choicesTarget.appendChild(button)
    })
  }

  selectVariant(variant) {
    this.variantIdTarget.value = variant.id
    this.lookupInputTarget.value = variant.sku
    if (this.hasUnitPriceTarget && !this.unitPriceTarget.value) {
      this.unitPriceTarget.value = (variant.selling_price_cents / 100).toFixed(2)
    }
    this.previewTarget.textContent = `${variant.sku} — ${variant.name} | On hand: ${variant.quantity_on_hand ?? 0} | ${variant.selling_price_cents}c`
    this.clearChoices()
    this.showMessage("")
  }

  submitLine(event) {
    event.preventDefault()
    if (!this.variantIdTarget.value) {
      this.showMessage("Select a variant before adding.")
      return
    }

    this.formTarget.requestSubmit()
  }

  variantLabel(variant) {
    const condition = variant.condition ? ` (${variant.condition})` : ""
    return `${variant.sku} — ${variant.name}${condition}`
  }

  showMessage(message) {
    if (!this.hasMessageTarget) return
    this.messageTarget.textContent = message
    this.messageTarget.hidden = !message
  }

  clearChoices() {
    this.choicesTarget.innerHTML = ""
  }
}
