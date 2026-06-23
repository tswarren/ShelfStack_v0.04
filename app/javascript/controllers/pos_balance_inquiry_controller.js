import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "status", "result"]
  static values = {
    lookupUrl: String
  }

  connect() {
    this.inputTarget?.focus()
  }

  lookup(event) {
    if (event.type === "keydown" && event.key !== "Enter") return
    event.preventDefault()

    const code = this.inputTarget?.value?.trim()
    if (!code) {
      this.setStatus("Enter or scan a gift card or store credit number.", true)
      return
    }

    const url = new URL(this.lookupUrlValue, window.location.origin)
    url.searchParams.set("code", code)
    url.searchParams.set("purpose", "balance_inquiry")

    fetch(url, {
      headers: {
        Accept: "application/json",
        "X-CSRF-Token": this.csrfToken
      }
    })
      .then((response) => response.json().then((data) => ({ ok: response.ok, data })))
      .then(({ ok, data }) => {
        if (!ok) {
          this.clearResult()
          this.setStatus(data.message || "Unable to look up that number.", true)
          return
        }

        this.setStatus("")
        this.showResult(data)
      })
      .catch(() => {
        this.clearResult()
        this.setStatus("Unable to look up balance.", true)
      })
  }

  showResult(data) {
    if (!this.hasResultTarget) return

    const accountLabel = data.account_type === "gift_card" ? "Gift card" : "Store credit"
    const holder = data.holder_name ? ` · ${data.holder_name}` : ""
    this.resultTarget.innerHTML = `
      <p class="ss-pos-balance-inquiry__account-type"><strong>${accountLabel}</strong>${this.escapeHtml(holder)}</p>
      <p class="ss-pos-balance-inquiry__identifier">${this.escapeHtml(data.display_value_masked)}</p>
      <p class="ss-pos-balance-inquiry__balance">Balance <strong>${this.formatMoney(data.current_balance_cents)}</strong></p>
    `
    this.resultTarget.hidden = false
  }

  clearResult() {
    if (!this.hasResultTarget) return

    this.resultTarget.innerHTML = ""
    this.resultTarget.hidden = true
  }

  setStatus(message, isError = false) {
    if (!this.hasStatusTarget) return

    this.statusTarget.textContent = message
    this.statusTarget.classList.toggle("ss-pos-alert--error", isError)
    this.statusTarget.hidden = !message
  }

  formatMoney(cents) {
    return `$${(cents / 100).toFixed(2)}`
  }

  escapeHtml(value) {
    return value
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
  }

  get csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content
  }
}
