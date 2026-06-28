import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    autoClearMs: { type: Number, default: 5000 }
  }

  connect() {
    if (this.element.classList.contains("ss-pos-alert--error")) return

    this.timeoutId = window.setTimeout(() => this.dismiss(), this.autoClearMsValue)
  }

  disconnect() {
    if (this.timeoutId) window.clearTimeout(this.timeoutId)
  }

  dismiss(event) {
    event?.preventDefault()
    if (this.timeoutId) {
      window.clearTimeout(this.timeoutId)
      this.timeoutId = null
    }

    this.element.remove()
    const container = document.getElementById("pos_flash")
    if (container && !container.querySelector(".ss-pos-alert")) {
      container.innerHTML = ""
    }
  }
}
