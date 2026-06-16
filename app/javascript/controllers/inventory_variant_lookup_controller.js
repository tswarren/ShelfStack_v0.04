import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "lookupInput",
    "variantId",
    "preview",
    "message",
    "choices",
    "line"
  ]

  static values = {
    url: String,
    initialSku: String,
    initialVariantId: String,
    initialLabel: String,
    initialOnHand: String
  }

  connect() {
    if (this.hasInitialVariantIdValue && this.initialVariantIdValue) {
      this.variantIdTarget.value = this.initialVariantIdValue
      this.lookupInputTarget.value = this.initialSkuValue || ""
      this.renderSelected({
        sku: this.initialSkuValue,
        name: this.initialLabelValue,
        quantity_on_hand: this.initialOnHandValue
      })
    }
  }

  lookupExact(event) {
    if (event.type === "keydown" && event.key !== "Enter") return
    if (event.type === "keydown") event.preventDefault()

    this.clearChoices()
    const query = this.lookupInputTarget.value.trim()
    if (!query) {
      this.clearSelection("Enter a SKU or barcode.")
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
      .catch(() => {
        this.messageTarget.textContent = "Unable to look up variant right now."
        this.messageTarget.className = "ss-hint ss-hint--warning"
      })
  }

  renderResult(data) {
    this.messageTarget.textContent = data.message || ""
    this.messageTarget.className = data.message ? "ss-hint ss-hint--warning" : "ss-hint"

    if (data.status === "found") {
      this.selectVariant(data.variants[0])
      return
    }

    if (data.status === "ineligible") {
      this.variantIdTarget.value = ""
      this.previewTarget.textContent = ""
      return
    }

    if (data.status === "ambiguous" || data.status === "search") {
      this.renderChoices(data.variants)
      this.variantIdTarget.value = ""
      this.previewTarget.textContent = ""
      return
    }

    this.clearSelection(data.message)
  }

  renderChoices(variants) {
    this.choicesTarget.innerHTML = ""
    variants.forEach((variant) => {
      const button = document.createElement("button")
      button.type = "button"
      button.className = "ss-btn ss-btn--secondary ss-variant-choice"
      button.textContent = this.variantLabel(variant)
      button.addEventListener("click", () => this.selectVariant(variant))
      this.choicesTarget.appendChild(button)
    })
  }

  selectVariant(variant) {
    if (!variant.eligible) {
      this.variantIdTarget.value = ""
      this.previewTarget.textContent = ""
      this.messageTarget.textContent = `Variant ${variant.sku} is not inventory-eligible (${variant.inventory_behavior}).`
      this.messageTarget.className = "ss-hint ss-hint--warning"
      this.clearChoices()
      return
    }

    this.variantIdTarget.value = variant.id
    this.lookupInputTarget.value = variant.sku
    this.renderSelected(variant)
    this.clearChoices()
    this.messageTarget.textContent = ""
    this.messageTarget.className = "ss-hint"
  }

  renderSelected(variant) {
    const onHand = variant.quantity_on_hand ?? this.initialOnHandValue ?? "0"
    this.previewTarget.textContent = `${variant.sku} — ${variant.name}${variant.condition ? ` (${variant.condition})` : ""} | On hand: ${onHand}`
  }

  variantLabel(variant) {
    const condition = variant.condition ? ` (${variant.condition})` : ""
    return `${variant.sku} — ${variant.name}${condition}`
  }

  clearSelection(message) {
    this.variantIdTarget.value = ""
    this.previewTarget.textContent = ""
    if (message) {
      this.messageTarget.textContent = message
      this.messageTarget.className = "ss-hint ss-hint--warning"
    }
  }

  clearChoices() {
    this.choicesTarget.innerHTML = ""
  }
}
