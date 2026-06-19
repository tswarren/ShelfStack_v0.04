import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "lookupInput",
    "query",
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
    returnMode: { type: Boolean, default: false },
    mode: { type: String, default: "sale" },
    autoAdd: { type: Boolean, default: true }
  }

  connect() {
    this.element.addEventListener("pos-command-bar:variantLookup", (event) => {
      this.handleVariantLookup(event.detail)
    })
    this.element.addEventListener("pos-command-bar:message", (event) => {
      this.showMessage(event.detail.message)
    })
    this.focusInput()
  }

  focusInput() {
    this.inputElement?.focus()
  }

  lookupExact(event) {
    if (event.type === "keydown" && event.key !== "Enter") return
    if (event.type === "keydown") event.preventDefault()

    const query = this.inputElement?.value.trim()
    if (!query) {
      this.showMessage("Enter a SKU or barcode.")
      return
    }

    this.exactLookup = true
    this.fetchLookup({ q: query, mode: "exact" })
  }

  search() {
    this.exactLookup = false
    const query = this.inputElement?.value.trim()
    if (!query || query.length < 2) {
      this.clearChoices()
      return
    }

    this.fetchLookup({ q: query, mode: "search" })
  }

  handleVariantLookup(payload) {
    if (payload.status === "found" && payload.variants.length === 1) {
      this.selectVariant(payload.variants[0], { autoAdd: true })
      return
    }

    if (payload.variants?.length) {
      this.renderChoices(payload.variants)
      this.showMessage(payload.status === "ambiguous" ? "Multiple variants matched. Choose one." : "")
    }
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
      const card = document.createElement("button")
      card.type = "button"
      card.className = "ss-pos-choice-card"
      card.innerHTML = this.choiceCardHtml(variant)
      card.addEventListener("click", () => this.selectVariant(variant, { autoAdd: true }))
      this.choicesTarget.appendChild(card)
    })
  }

  choiceCardHtml(variant) {
    const price = `$${(variant.selling_price_cents / 100).toFixed(2)}`
    const condition = variant.condition || "—"
    const behavior = (variant.inventory_behavior || "standard").replaceAll("_", " ")
    const inactive = (!variant.active || !variant.product_active)
      ? `<span class="ss-pos-choice-card__warn">Inactive variant — confirm required</span>`
      : ""

    return `
      <strong class="ss-pos-choice-card__sku">${variant.sku}</strong>
      <span class="ss-pos-choice-card__name">${variant.name}</span>
      <span class="ss-pos-choice-card__meta">${condition} · On hand ${variant.quantity_on_hand ?? 0} · ${price} · ${behavior}</span>
      ${inactive}
    `
  }

  selectVariant(variant, { autoAdd = false } = {}) {
    if (this.hasVariantIdTarget) {
      this.variantIdTarget.value = variant.id
    }
    if (this.inputElement) {
      this.inputElement.value = variant.sku
    }
    if (this.hasPreviewTarget) {
      this.previewTarget.innerHTML = this.formatPreview(variant)
    }
    this.clearChoices()
    this.showMessage("")

    if (autoAdd) {
      this.addVariant(variant)
    }
  }

  addVariant(variant) {
    const body = new FormData()
    body.append("product_variant_id", variant.id)
    body.append("quantity", this.returnModeValue ? "-1" : "1")
    body.append("return_mode", this.returnModeValue ? "1" : "0")
    body.append("entry_action", this.returnModeValue ? "return_no_receipt" : "sale")

    fetch(this.addUrlValue, {
      method: "POST",
      headers: {
        "X-CSRF-Token": this.csrfToken,
        Accept: "text/vnd.turbo-stream.html"
      },
      body
    })
      .then((response) => {
        if (!response.ok) throw new Error(`Add line failed (${response.status})`)
        return response.text()
      })
      .then((html) => {
        window.Turbo.renderStreamMessage(html)
        this.inputElement.value = ""
        this.clearChoices()
        this.showMessage("")
        this.focusInput()
      })
      .catch(() => this.showMessage("Unable to add line."))
  }

  formatPreview(variant) {
    const price = `$${(variant.selling_price_cents / 100).toFixed(2)}`
    const onHand = variant.quantity_on_hand ?? 0
    return `${variant.sku} — ${variant.name}<br><span class="ss-pos-preview-meta">On hand: ${onHand} · ${price}</span>`
  }

  showMessage(message) {
    if (!this.hasMessageTarget) return
    this.messageTarget.textContent = message || ""
    this.messageTarget.hidden = !message
  }

  clearChoices() {
    if (this.hasChoicesTarget) {
      this.choicesTarget.innerHTML = ""
    }
  }

  get inputElement() {
    if (this.hasQueryTarget) return this.queryTarget
    if (this.hasLookupInputTarget) return this.lookupInputTarget
    return null
  }

  get csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content
  }
}
