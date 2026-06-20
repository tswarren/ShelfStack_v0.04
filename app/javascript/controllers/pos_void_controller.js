import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "reasonField", "notesField", "form", "authorizationId"]

  static values = {
    transactionId: String
  }

  connect() {
    this.onAuthorizationGranted = this.onAuthorizationGranted.bind(this)
    document.addEventListener("pos:authorization-granted", this.onAuthorizationGranted)
  }

  disconnect() {
    document.removeEventListener("pos:authorization-granted", this.onAuthorizationGranted)
  }

  open(event) {
    event.preventDefault()
    this.modalTarget.hidden = false
    if (this.hasReasonFieldTarget) this.reasonFieldTarget.focus()
  }

  close(event) {
    if (event) event.preventDefault()
    this.modalTarget.hidden = true
    if (this.hasAuthorizationIdTarget) this.authorizationIdTarget.value = ""
  }

  submit(event) {
    if (!this.hasReasonFieldTarget || !this.reasonFieldTarget.value) {
      event.preventDefault()
      alert("Select a void reason before continuing.")
      return
    }

    if (!this.hasAuthorizationIdTarget || !this.authorizationIdTarget.value) {
      event.preventDefault()
      document.dispatchEvent(new CustomEvent("pos:authorization-request", {
        detail: {
          authorizationType: "void_transaction",
          message: "Voiding a completed transaction requires manager approval.",
          transactionId: this.transactionIdValue
        }
      }))
    }
  }

  onAuthorizationGranted(event) {
    if (event.detail?.authorizationType !== "void_transaction") return
    if (!this.hasAuthorizationIdTarget || !this.hasFormTarget) return

    this.authorizationIdTarget.value = event.detail.authorizationId
    this.formTarget.requestSubmit()
  }
}
