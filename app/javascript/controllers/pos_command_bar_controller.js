import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "returnToggle", "receiptPanel", "openRingPanel", "openRingReturnMode"]
  static values = {
    routeUrl: String
  }

  connect() {
    this.focusInput()
  }

  toggleReturnMode() {
    const returnMode = this.returnToggleTarget.checked
    this.element.dataset.posLineEntryReturnModeValue = returnMode ? "true" : "false"
    this.syncOpenRingReturnMode(returnMode)
  }

  syncOpenRingReturnMode(returnMode = this.returnToggleTarget.checked) {
    if (!this.hasOpenRingReturnModeTarget) return

    this.openRingReturnModeTarget.value = returnMode ? "1" : "0"
  }

  submit(event) {
    if (event.type === "keydown" && event.key !== "Enter") return
    event.preventDefault()

    const input = this.inputTarget.value.trim()
    if (!input) return

    const body = new FormData()
    body.append("input", input)
    body.append("return_mode", this.returnToggleTarget.checked ? "1" : "0")

    fetch(this.routeUrlValue, {
      method: "POST",
      headers: {
        "X-CSRF-Token": this.csrfToken,
        Accept: "application/json"
      },
      body
    })
      .then((response) => response.json())
      .then((data) => this.handleRoute(data, input))
      .catch(() => this.dispatchMessage("Unable to process entry."))
  }

  handleRoute(data, input) {
    this.hidePanels()

    switch (data.action) {
      case "variant_lookup":
        this.dispatch("variantLookup", { detail: data.payload })
        break
      case "receipt_lookup":
        this.showReceiptPanel(input)
        break
      case "open_ring_offer":
        this.showOpenRingPanel(data.payload)
        break
      default:
        this.dispatchMessage(data.message)
    }
  }

  showReceiptPanel(transactionNumber) {
    this.receiptPanelTarget.hidden = false
    const receiptInput = this.receiptPanelTarget.querySelector("[data-pos-return-lookup-target='input']")
    if (receiptInput) {
      receiptInput.value = transactionNumber
      receiptInput.dispatchEvent(new Event("change", { bubbles: true }))
      this.receiptPanelTarget.querySelector("[data-action*='pos-return-lookup#lookup']")?.click()
    }
  }

  showOpenRingPanel(payload) {
    this.syncOpenRingReturnMode()
    this.openRingPanelTarget.hidden = false
    const priceField = this.openRingPanelTarget.querySelector("[name='unit_price']")
    if (priceField && payload.amount_cents) {
      priceField.value = (payload.amount_cents / 100).toFixed(2)
    }
    const descriptionField = this.openRingPanelTarget.querySelector("[name='description']")
    if (descriptionField && payload.query) {
      descriptionField.value = payload.query
    }
  }

  hidePanels() {
    if (this.hasReceiptPanelTarget) this.receiptPanelTarget.hidden = true
    if (this.hasOpenRingPanelTarget) this.openRingPanelTarget.hidden = true
  }

  closeOpenRingPanel(event) {
    event?.preventDefault()
    if (!this.hasOpenRingPanelTarget) return

    this.openRingPanelTarget.hidden = true
    this.openRingPanelTarget.querySelector("form")?.reset()
    this.focusInput()
  }

  closeReceiptPanel(event) {
    event?.preventDefault()
    if (!this.hasReceiptPanelTarget) return

    this.receiptPanelTarget.hidden = true
    const input = this.receiptPanelTarget.querySelector("[data-pos-return-lookup-target='input']")
    if (input) input.value = ""
    const results = this.receiptPanelTarget.querySelector("[data-pos-return-lookup-target='results']")
    if (results) results.innerHTML = ""
    const message = this.receiptPanelTarget.querySelector("[data-pos-return-lookup-target='message']")
    if (message) {
      message.textContent = ""
      message.hidden = true
    }
    this.focusInput()
  }

  openRingSubmitted(event) {
    if (event.detail.success) {
      this.closeOpenRingPanel()
    }
  }

  focusInput() {
    this.inputTarget?.focus()
  }

  dispatchMessage(message) {
    this.dispatch("message", { detail: { message } })
  }

  get csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content
  }
}
