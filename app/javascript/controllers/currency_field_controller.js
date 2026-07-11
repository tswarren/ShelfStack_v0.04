import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display", "cents"]

  connect() {
    this.syncFromCents()
  }

  updateCents() {
    const dollars = parseFloat(this.displayTarget.value)
    if (Number.isNaN(dollars)) {
      this.centsTarget.value = ""
      return
    }
    this.centsTarget.value = Math.round(dollars * 100)
  }

  syncFromCents() {
    const cents = parseInt(this.centsTarget.value, 10)
    if (Number.isNaN(cents)) return
    this.displayTarget.value = (cents / 100).toFixed(2)
  }
}
