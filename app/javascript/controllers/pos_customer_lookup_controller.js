import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["actions", "attachButton", "startSaleButton"]
  static values = {
    attachUrl: String,
    startSaleUrl: String,
    transactionId: String
  }

  connect() {
    this.boundCustomerSelected = this.onCustomerSelected.bind(this)
    this.element.addEventListener("customer-lookup:selected", this.boundCustomerSelected)
    this.boundCustomerCleared = this.onCustomerCleared.bind(this)
    this.element.addEventListener("customer-lookup:cleared", this.boundCustomerCleared)
    this.syncActions()
  }

  disconnect() {
    this.element.removeEventListener("customer-lookup:selected", this.boundCustomerSelected)
    this.element.removeEventListener("customer-lookup:cleared", this.boundCustomerCleared)
  }

  onCustomerSelected() {
    this.syncActions()
  }

  onCustomerCleared() {
    this.syncActions()
  }

  syncActions() {
    if (!this.hasActionsTarget) return

    const customerId = this.element.querySelector("[data-customer-lookup-target='customerId']")?.value
    const visible = Boolean(customerId)
    this.actionsTarget.hidden = !visible
  }

  attach(event) {
    event.preventDefault()
    if (!this.attachUrlValue) return

    const customerId = this.element.querySelector("[data-customer-lookup-target='customerId']")?.value
    if (!customerId) return

    const body = new FormData()
    body.append("customer_id", customerId)

    fetch(this.attachUrlValue, {
      method: "PATCH",
      headers: {
        "X-CSRF-Token": this.csrfToken,
        Accept: "text/vnd.turbo-stream.html"
      },
      body
    })
      .then((response) => {
        if (!response.ok) throw new Error("failed")
        return response.text()
      })
      .then((html) => {
        Turbo.renderStreamMessage(html)
        this.closeModal()
        this.focusCommandInput()
      })
      .catch(() => this.dispatchMessage("Unable to attach customer."))
  }

  startSale(event) {
    event.preventDefault()
    if (!this.startSaleUrlValue) return

    const customerId = this.element.querySelector("[data-customer-lookup-target='customerId']")?.value
    if (!customerId) return

    const body = new FormData()
    body.append("customer_id", customerId)

    fetch(this.startSaleUrlValue, {
      method: "POST",
      headers: {
        "X-CSRF-Token": this.csrfToken,
        Accept: "application/json"
      },
      body
    })
      .then((response) => response.json())
      .then((data) => {
        if (data.action === "redirect" && data.payload?.url) {
          window.location.href = data.payload.url
          return
        }
        this.dispatchMessage(data.message || "Unable to start sale.")
      })
      .catch(() => this.dispatchMessage("Unable to start sale."))
  }

  resetIfClosed(event) {
    if (event.target?.id !== "pos-customer-lookup-modal") return

    const lookupInput = this.element.querySelector("[data-customer-lookup-target='lookupInput']")
    const customerId = this.element.querySelector("[data-customer-lookup-target='customerId']")
    const preview = this.element.querySelector("[data-customer-lookup-target='preview']")
    const message = this.element.querySelector("[data-customer-lookup-target='message']")
    const choices = this.element.querySelector("[data-customer-lookup-target='choices']")

    if (lookupInput) lookupInput.value = ""
    if (customerId) customerId.value = ""
    if (preview) preview.textContent = ""
    if (message) message.textContent = ""
    if (choices) choices.innerHTML = ""
    if (this.hasActionsTarget) this.actionsTarget.hidden = true
  }

  closeModal() {
    const modal = document.getElementById("pos-customer-lookup-modal")
    const controller = this.application.getControllerForElementAndIdentifier(modal, "modal")
    controller?.close()
  }

  focusCommandInput() {
    document.querySelector("[data-pos-command-bar-target='input']")?.focus()
  }

  dispatchMessage(message) {
    document.dispatchEvent(new CustomEvent("pos:command-message", { detail: { message } }))
  }

  get csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content
  }
}
