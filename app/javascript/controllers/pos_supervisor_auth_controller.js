import { Controller } from "@hotwired/stimulus"
import { closeOverlay, openOverlayById } from "shelfstack/overlay_shell"

const MODAL_ID = "pos-supervisor-auth-modal"

export default class extends Controller {
  static targets = [
    "message",
    "error",
    "form",
    "authorizationType",
    "transactionId",
    "registerSessionId",
    "managerUsername",
    "managerPin"
  ]

  connect() {
    this.boundOpen = this.open.bind(this)
    this.boundFocusFirst = this.focusFirst.bind(this)
    document.addEventListener("pos:authorization-request", this.boundOpen)
    document.addEventListener("modal:opened", this.boundFocusFirst)
  }

  disconnect() {
    document.removeEventListener("pos:authorization-request", this.boundOpen)
    document.removeEventListener("modal:opened", this.boundFocusFirst)
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
    this.openModal()
  }

  focusFirst(event) {
    if (event.target?.id !== MODAL_ID) return

    this.managerUsernameTarget?.focus()
  }

  close(event) {
    if (event) event.preventDefault()
    this.closeModal()
    this.formTarget.reset()
  }

  submit(event) {
    event.preventDefault()

    const body = new FormData(this.formTarget)
    fetch(this.formTarget.action, {
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

  openModal() {
    openOverlayById(this.application, "modal", MODAL_ID)
  }

  closeModal() {
    const modal = document.getElementById(MODAL_ID)
    if (!modal) return

    const controller = this.application.getControllerForElementAndIdentifier(modal, "modal")
    if (controller) closeOverlay(controller, { force: true })
  }
}
