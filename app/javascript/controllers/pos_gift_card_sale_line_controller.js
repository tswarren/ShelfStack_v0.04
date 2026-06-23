import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["lookupField", "lookupStatus"]
  static values = {
    lookupUrl: String,
    lineId: Number
  }

  submitCardNumber() {
    const code = this.lookupFieldTarget?.value?.trim()

    if (!code) {
      this.setStatus("A card number will be auto-generated at completion.")
      this.submitForm({ clear_card_number: "1" })
      return
    }

    const url = new URL(this.lookupUrlValue, window.location.origin)
    url.searchParams.set("code", code)
    url.searchParams.set("tender_type", "gift_card")
    url.searchParams.set("purpose", "gift_card_sale")

    fetch(url, {
      headers: {
        Accept: "application/json",
        "X-CSRF-Token": this.csrfToken
      }
    })
      .then((response) => response.json().then((data) => ({ ok: response.ok, status: response.status, data })))
      .then(({ ok, data }) => {
        if (ok) {
          this.setStatus(`Reload ${data.display_value_masked} — balance ${this.formatMoney(data.current_balance_cents)}`)
        } else if (data.status === "not_found") {
          this.setStatus(`Assign new card ${this.maskCardNumber(code)}`)
        } else {
          this.setStatus(data.message || "Unable to use that card number.", true)
          return
        }

        this.submitForm({ lookup_code: code })
      })
      .catch(() => this.setStatus("Unable to save card number.", true))
  }

  submitForm(extraFields = {}) {
    const form = this.element.querySelector("form")
    if (!form) return

    ;["lookup_code", "clear_card_number", "generate_identifier"].forEach((name) => {
      form.querySelector(`[name="${name}"]`)?.remove()
    })

    Object.entries(extraFields).forEach(([name, value]) => {
      const field = document.createElement("input")
      field.type = "hidden"
      field.name = name
      field.value = value
      form.appendChild(field)
    })

    if (typeof form.requestSubmit === "function") {
      form.requestSubmit()
    } else {
      form.submit()
    }
  }

  setStatus(message, isError = false) {
    if (!this.hasLookupStatusTarget) return

    this.lookupStatusTarget.textContent = message
    this.lookupStatusTarget.classList.toggle("ss-pos-alert--error", isError)
  }

  maskCardNumber(value) {
    const digits = value.replace(/\s+/g, "")
    if (digits.length <= 4) return digits

    return `${"*".repeat(Math.max(digits.length - 4, 0))}${digits.slice(-4)}`
  }

  formatMoney(cents) {
    return `$${(cents / 100).toFixed(2)}`
  }

  get csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content
  }
}
