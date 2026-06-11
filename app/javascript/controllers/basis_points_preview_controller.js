import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "output"]

  update() {
    const bps = parseInt(this.inputTarget.value, 10)
    this.outputTarget.textContent = isNaN(bps) ? "—" : `${(bps / 100.0).toFixed(2)}%`
  }
}
