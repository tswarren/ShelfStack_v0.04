import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "keyCount" ]

  recordKeydown() {
    if (!this.hasKeyCountTarget) return

    const current = Number.parseInt(this.keyCountTarget.textContent, 10) || 0
    this.keyCountTarget.textContent = String(current + 1)
  }
}
