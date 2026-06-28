import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    focus: { type: String, default: "reason" },
    openOnConnect: { type: Boolean, default: false }
  }

  connect() {
    if (this.openOnConnectValue) {
      this.dispatchOpen()
      this.element.remove()
    }
  }

  open(event) {
    event?.preventDefault?.()
    this.dispatchOpen()
  }

  dispatchOpen() {
    document.dispatchEvent(new CustomEvent("pos:open-transaction-discount-modal", {
      detail: { focus: this.focusValue }
    }))
  }
}
