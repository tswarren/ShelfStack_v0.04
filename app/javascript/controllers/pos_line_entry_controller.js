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
    "form",
    "entryActionField"
  ]

  static values = {
    url: String,
    addUrl: String,
    mode: { type: String, default: "sale" },
    autoAdd: { type: Boolean, default: true }
  }

  connect() {
    if (this.hasLookupInputTarget) {
      this.lookupInputTarget.focus()
    }
  }

  lookupExact(event) {
    if (event.type === "keydown" && event.key !== "Enter") return
    if (event.type === "keydown") event.preventDefault()

    const query = this.lookupInputTarget.value.trim()
    if (!query) {
      this.showMessage("Enter a SKU or barcode.")
      return
    }

    this.exactLookup = true
    this.fetchLookup({ q: query, mode: "exact" })
  }

  search() {
    this.exactLookup = false
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
      this.selectVariant(data.variants[0], { autoAdd: this.exactLookup })
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
      button.addEventListener("click", () => this.selectVariant(variant, { autoAdd: true }))
      this.choicesTarget.appendChild(button)
    })
  }

  selectVariant(variant, { autoAdd = false } = {}) {
    this.variantIdTarget.value = variant.id
    this.lookupInputTarget.value = variant.sku
    if (this.hasUnitPriceTarget && !this.unitPriceTarget.value) {
      this.unitPriceTarget.value = (variant.selling_price_cents / 100).toFixed(2)
    }
    this.previewTarget.innerHTML = this.formatPreview(variant)
    this.clearChoices()
    this.showMessage("")

    if (autoAdd && this.autoAddValue && this.hasFormTarget) {
      this.formTarget.requestSubmit()
    }
  }

  formatPreview(variant) {
    const price = `$${(variant.selling_price_cents / 100).toFixed(2)}`
    const onHand = variant.quantity_on_hand ?? 0
    return `${variant.sku} — ${variant.name}<br><span class="ss-pos-preview-meta">On hand: ${onHand} · ${price}</span>`
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
