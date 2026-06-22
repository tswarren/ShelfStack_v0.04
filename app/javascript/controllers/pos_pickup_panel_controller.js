import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["query", "requestNumber", "results", "message"]
  static values = {
    url: String,
    addReservationUrl: String
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
    if (this.hasRequestNumberTarget && this.requestNumberTarget.value.trim()) {
      body.append("request_number", this.requestNumberTarget.value.trim())
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
    this.resultsTarget.querySelectorAll("[data-reservation-id]").forEach((button) => {
      button.addEventListener("click", () => this.addReservation(button.dataset.reservationId))
    })
  }

  rowHtml(row) {
    const expires = row.expires_at ? ` · Expires ${new Date(row.expires_at).toLocaleDateString()}` : ""
    return `
      <button type="button" class="ss-pos-choice-card" data-reservation-id="${row.reservation_id}">
        <strong class="ss-pos-choice-card__sku">${row.variant_sku}</strong>
        <span class="ss-pos-choice-card__name">${row.variant_name}</span>
        <span class="ss-pos-choice-card__meta">Pickup for ${row.customer_name} · Qty ${row.quantity}${expires}</span>
        ${row.request_number ? `<span class="ss-pos-choice-card__meta">Request ${row.request_number}</span>` : ""}
      </button>
    `
  }

  addReservation(reservationId) {
    const body = new FormData()
    body.append("inventory_reservation_id", reservationId)

    fetch(this.addReservationUrlValue, {
      method: "POST",
      headers: {
        "X-CSRF-Token": this.csrfToken,
        Accept: "text/vnd.turbo-stream.html"
      },
      body
    })
      .then((response) => {
        if (!response.ok) throw new Error(`Add pickup line failed (${response.status})`)
        return response.text()
      })
      .then((html) => {
        window.Turbo.renderStreamMessage(html)
        if (this.hasQueryTarget) this.queryTarget.value = ""
        if (this.hasRequestNumberTarget) this.requestNumberTarget.value = ""
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
