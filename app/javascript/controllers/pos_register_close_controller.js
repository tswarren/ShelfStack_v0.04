import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["countedField", "varianceDisplay"]
  static values = { expectedCents: Number }

  connect() {
    this.updateVariance()
  }

  updateVariance() {
    if (!this.hasCountedFieldTarget || !this.hasVarianceDisplayTarget) return

    const countedCents = Math.round(parseFloat(this.countedFieldTarget.value || "0") * 100)
    const varianceCents = countedCents - this.expectedCentsValue
    const formatted = this.formatMoney(varianceCents)
    this.varianceDisplayTarget.textContent = formatted
    this.varianceDisplayTarget.classList.toggle("ss-pos-variance--nonzero", varianceCents !== 0)
  }

  formatMoney(cents) {
    const prefix = cents < 0 ? "-" : ""
    return `${prefix}$${(Math.abs(cents) / 100).toFixed(2)}`
  }
}
