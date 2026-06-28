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
    if (!this.hasActionsTarget) return

    this.element.querySelector("[data-customer-lookup-target='lookupInput']").value = ""
    this.element.querySelector("[data-customer-lookup-target='customerId']").value = ""
    this.element.querySelector("[data-customer-lookup-target='preview']").textContent = ""
    this.element.querySelector("[data-customer-lookup-target='message']").textContent = ""
    this.element.querySelector("[data-customer-lookup-target='choices']").innerHTML = ""
    this.actionsTarget.hidden = true
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
