import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["query", "demandNumber", "results", "message"]
  static values = {
    url: String,
    addPickupUrl: String,
    redirectOnSuccess: { type: Boolean, default: false }
  }

  search(event) {
    event?.preventDefault()
    this.fetchPickups()
  }

  fetchPickups() {
    const body = new FormData()
    if (this.hasQueryTarget && this.queryTarget.value.trim()) {
      body.append("query", this.queryTarget.value.trim())
    }
    if (this.hasDemandNumberTarget && this.demandNumberTarget.value.trim()) {
      body.append("demand_number", this.demandNumberTarget.value.trim())
    }

    fetch(this.urlValue, {
      method: "POST",
      headers: {
        "X-CSRF-Token": this.csrfToken,
        Accept: "application/json"
      },
      body
    })
      .then((response) => response.json())
      .then((data) => this.renderResults(data.pickups || []))
      .catch(() => this.showMessage("Unable to load pickup items."))
  }

  renderResults(pickups) {
    if (!this.hasResultsTarget) return

    if (pickups.length === 0) {
      this.resultsTarget.innerHTML = ""
      this.showMessage("No ready-for-pickup items found.")
      return
    }

    this.showMessage("")
    this.resultsTarget.innerHTML = pickups.map((row) => this.rowHtml(row)).join("")
    this.resultsTarget.querySelectorAll("[data-add-pickup]").forEach((button) => {
      button.addEventListener("click", () => {
        const card = button.closest("[data-allocation-id]")
        const qtyInput = card?.querySelector("[data-pickup-qty]")
        const quantity = parseInt(qtyInput?.value, 10) || 1
        this.addPickup(button.dataset.allocationId, quantity)
      })
    })
  }

  rowHtml(row) {
    const expires = row.expires_at ? ` · Expires ${new Date(row.expires_at).toLocaleDateString()}` : ""
    const maxQty = row.quantity || 1
    const allocationId = row.demand_allocation_id
    return `
      <div class="ss-pos-choice-card ss-pos-pickup-card" data-allocation-id="${allocationId}">
        <strong class="ss-pos-choice-card__sku">${row.variant_sku}</strong>
        <span class="ss-pos-choice-card__name">${row.variant_name}</span>
        <span class="ss-pos-choice-card__meta">Pickup for ${row.customer_name} · ${maxQty} allocated${expires}</span>
        ${row.demand_number ? `<span class="ss-pos-choice-card__meta">Demand ${row.demand_number}</span>` : ""}
        <div class="ss-pos-pickup-card__actions">
          <label class="ss-pos-pickup-card__qty">
            <span class="visually-hidden">Pickup quantity</span>
            <input type="number" min="1" max="${maxQty}" value="${maxQty}" data-pickup-qty class="ss-input ss-input--small" />
          </label>
          <button type="button" class="ss-btn ss-btn-secondary ss-btn--small" data-add-pickup data-allocation-id="${allocationId}">
            Add to cart
          </button>
        </div>
      </div>
    `
  }

  addPickup(allocationId, quantity = 1) {
    const body = new FormData()
    body.append("demand_allocation_id", allocationId)
    body.append("quantity", quantity)

    fetch(this.addPickupUrlValue, {
      method: "POST",
      headers: {
        "X-CSRF-Token": this.csrfToken,
        Accept: this.redirectOnSuccessValue ? "text/html" : "text/vnd.turbo-stream.html"
      },
      body
    })
      .then((response) => {
        if (this.redirectOnSuccessValue && response.redirected) {
          window.location.href = response.url
          return null
        }
        if (!response.ok) throw new Error(`Add pickup line failed (${response.status})`)
        return response.text()
      })
      .then((html) => {
        if (!html) return

        window.Turbo.renderStreamMessage(html)
        if (this.hasQueryTarget) this.queryTarget.value = ""
        if (this.hasDemandNumberTarget) this.demandNumberTarget.value = ""
        this.renderResults([])
      })
      .catch(() => this.showMessage("Unable to add pickup line."))
  }

  showMessage(text) {
    if (this.hasMessageTarget) this.messageTarget.textContent = text
  }

  get csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content
  }
}
