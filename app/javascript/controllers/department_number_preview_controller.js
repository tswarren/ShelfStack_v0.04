import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "output"]

  update() {
    const value = this.inputTarget.value.trim()
    if (!/^\d+$/.test(value)) {
      this.outputTarget.textContent = value || "—"
      return
    }
    const numeric = parseInt(value, 10)
    if (numeric < 0 || numeric > 999) {
      this.outputTarget.textContent = value
      return
    }
    this.outputTarget.textContent = String(numeric).padStart(3, "0")
  }
}
