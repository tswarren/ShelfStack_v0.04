import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["proposed", "reasonGroup", "reason", "hint"]

  connect() {
    this.proposedTargets.forEach((input) => this.syncPair(input))
    this.proposedTargets.forEach((input) => {
      input.addEventListener("input", () => this.syncPair(input))
    })
  }

  syncPair(input) {
    const suggested = parseInt(input.dataset.buybackLinePricingSuggestedValue || "0", 10)
    const proposed = parseInt(input.value || "0", 10)
    const group = this.reasonGroupFor(input)
    const hint = this.hintFor(input)
    const reason = this.reasonFor(input)
    const changed = proposed !== suggested

    if (!group) return

    group.hidden = !changed
    if (hint) {
      const label = input.dataset.buybackLinePricingLabel || "Value"
      hint.textContent = changed
        ? `${label} changed from ${this.formatCents(suggested)} to ${this.formatCents(proposed)} — reason required`
        : ""
    }
    if (reason) {
      reason.required = changed
    }
  }

  reasonGroupFor(input) {
    const groups = this.reasonGroupTargets
    const index = this.proposedTargets.indexOf(input)
    return groups[index]
  }

  hintFor(input) {
    const hints = this.hintTargets
    const index = this.proposedTargets.indexOf(input)
    return hints[index]
  }

  reasonFor(input) {
    const reasons = this.reasonTargets
    const index = this.proposedTargets.indexOf(input)
    return reasons[index]
  }

  formatCents(cents) {
    return `$${(cents / 100).toFixed(2)}`
  }
}
