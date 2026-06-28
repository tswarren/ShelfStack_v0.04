import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    document.dispatchEvent(new CustomEvent("pos:open-transaction-discount-modal", {
      detail: { focus: "firstInvalid" }
    }))
  }
}
