import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "modal",
    "message",
    "error",
    "form",
    "authorizationType",
    "transactionId",
    "registerSessionId",
    "managerUsername",
    "managerPin"
  ]

  static values = {
    url: String
  }

  open(event) {
    const detail = event.detail || {}
    const authorizationType = detail.authorizationType || event.params?.authorizationType
    const message = detail.message
    const transactionId = detail.transactionId
    const registerSessionId = detail.registerSessionId

    if (!authorizationType) return

    this.authorizationTypeTarget.value = authorizationType
    if (this.hasTransactionIdTarget) {
      this.transactionIdTarget.value = transactionId || ""
    }
    if (this.hasRegisterSessionIdTarget) {
      this.registerSessionIdTarget.value = registerSessionId || ""
    }
    if (this.hasMessageTarget) {
      this.messageTarget.textContent = message || "A manager must approve this action."
    }
    this.errorTarget.hidden = true
    this.modalTarget.hidden = false
  }

  close(event) {
    if (event) event.preventDefault()
    this.modalTarget.hidden = true
    this.formTarget.reset()
  }

  submit(event) {
    event.preventDefault()

    const body = new FormData(this.formTarget)
    fetch(this.urlValue, {
      method: "POST",
      headers: {
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content,
        Accept: "application/json"
      },
      body
    })
      .then((response) => response.json().then((data) => ({ ok: response.ok, data })))
      .then(({ ok, data }) => {
        if (!ok) {
          this.errorTarget.textContent = data.error || "Authorization failed."
          this.errorTarget.hidden = false
          return
        }

        document.dispatchEvent(new CustomEvent("pos:authorization-granted", {
          detail: {
            authorizationId: data.authorization_id,
            authorizationType: data.authorization_type
          }
        }))
        this.close()
      })
      .catch(() => {
        this.errorTarget.textContent = "Unable to request authorization."
        this.errorTarget.hidden = false
      })
  }
}
