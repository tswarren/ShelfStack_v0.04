import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["identifier", "title", "form", "submit", "panel"]
  static values = { focusOnConnect: Boolean }

  connect() {
    if (this.focusOnConnectValue && this.hasIdentifierTarget) {
      this.identifierTarget.focus()
      this.identifierTarget.select()
    }
  }

  submit() {
    if (this.hasIdentifierTarget) {
      window.sessionStorage.setItem("buyback-intake-refocus", "1")
    }
  }

  identifierTargetConnected(element) {
    if (window.sessionStorage.getItem("buyback-intake-refocus") === "1") {
      window.sessionStorage.removeItem("buyback-intake-refocus")
      element.focus()
      element.select()
    }
  }
}
