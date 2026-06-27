import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "returnToggle", "receiptPanel", "openRingPanel", "openRingReturnMode", "giftCardPanel", "balancePanel", "transactionDiscountPanel"]
  static values = {
    routeUrl: String,
    addGiftCardUrl: String,
    returnMode: { type: Boolean, default: false }
  }

  connect() {
    this.focusInput()
    this.syncOpenRingReturnMode()
  }

  toggleReturnMode() {
    if (!this.hasReturnToggleTarget) return

    const returnMode = this.returnToggleTarget.checked
    this.returnModeValue = returnMode
    this.element.dataset.posLineEntryReturnModeValue = returnMode ? "true" : "false"
    this.syncOpenRingReturnMode(returnMode)
  }

  syncOpenRingReturnMode(returnMode = this.returnMode) {
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
    body.append("return_mode", this.returnMode ? "1" : "0")

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
      case "redirect":
        if (data.payload?.url) {
          if (data.message) this.dispatchMessage(data.message)
          window.location.href = data.payload.url
        }
        break
      case "message":
      case "help":
      case "disabled_command":
        this.dispatchMessage(data.message)
        break
      case "variant_lookup":
        this.dispatch("variantLookup", { detail: data.payload })
        break
      case "receipt_lookup":
        this.showReceiptPanel(input)
        break
      case "open_ring_offer":
        this.showOpenRingPanel(data.payload)
        break
      case "gift_card_sale":
        this.addGiftCardSale(data.payload)
        break
      case "gift_card_sale_offer":
        this.showGiftCardPanel(data.payload)
        break
      case "balance_inquiry_offer":
        this.showBalancePanel()
        break
      case "line_discount_offer":
        if (data.payload?.line_id) {
          this.openLineDiscount(data.payload.line_id)
        } else {
          this.dispatchMessage(data.message || "No line available for discount.")
        }
        break
      case "transaction_discount_offer":
        this.openTransactionDiscountPanel(true)
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

  showGiftCardPanel(payload) {
    if (!this.hasGiftCardPanelTarget) {
      this.dispatchMessage("Gift card sales are not available.")
      return
    }

    this.giftCardPanelTarget.hidden = false
    const priceField = this.giftCardPanelTarget.querySelector("[name='unit_price']")
    if (priceField && payload.amount_cents) {
      priceField.value = (payload.amount_cents / 100).toFixed(2)
    }
  }

  showBalancePanel() {
    if (!this.hasBalancePanelTarget) {
      this.dispatchMessage("Balance inquiry is not available.")
      return
    }

    this.balancePanelTarget.hidden = false
    const input = this.balancePanelTarget.querySelector("[data-pos-balance-inquiry-target='input']")
    input?.focus()
  }

  closeBalancePanel(event) {
    event?.preventDefault()
    if (!this.hasBalancePanelTarget) return

    this.balancePanelTarget.hidden = true
    const input = this.balancePanelTarget.querySelector("[data-pos-balance-inquiry-target='input']")
    if (input) input.value = ""
    const status = this.balancePanelTarget.querySelector("[data-pos-balance-inquiry-target='status']")
    if (status) {
      status.textContent = ""
      status.hidden = true
    }
    const result = this.balancePanelTarget.querySelector("[data-pos-balance-inquiry-target='result']")
    if (result) {
      result.innerHTML = ""
      result.hidden = true
    }
    this.focusInput()
  }

  addGiftCardSale(payload) {
    if (!this.addGiftCardUrlValue) {
      this.dispatchMessage("Gift card sales are not available.")
      return
    }

    const body = new FormData()
    body.append("amount_cents", payload.amount_cents)

    fetch(this.addGiftCardUrlValue, {
      method: "POST",
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
        this.inputTarget.value = ""
        this.focusInput()
      })
      .catch(() => this.dispatchMessage("Unable to add gift card sale."))
  }

  closeGiftCardPanel(event) {
    event?.preventDefault()
    if (!this.hasGiftCardPanelTarget) return

    this.giftCardPanelTarget.hidden = true
    this.giftCardPanelTarget.querySelector("form")?.reset()
    this.focusInput()
  }

  giftCardSubmitted(event) {
    if (event.detail.success) {
      this.closeGiftCardPanel()
    }
  }

  hidePanels() {
    if (this.hasReceiptPanelTarget) this.receiptPanelTarget.hidden = true
    if (this.hasOpenRingPanelTarget) this.openRingPanelTarget.hidden = true
    if (this.hasGiftCardPanelTarget) this.giftCardPanelTarget.hidden = true
    if (this.hasBalancePanelTarget) this.balancePanelTarget.hidden = true
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

  openLineDiscount(lineId) {
    this.inputTarget.value = ""
    document.dispatchEvent(new CustomEvent("pos:open-line-discount", {
      detail: { lineId: String(lineId) }
    }))
  }

  openTransactionDiscountPanel(open = true) {
    const panel = this.hasTransactionDiscountPanelTarget
      ? this.transactionDiscountPanelTarget
      : document.querySelector("[data-pos-command-bar-target='transactionDiscountPanel']")
    if (!panel) return

    panel.open = open
    panel.scrollIntoView({ behavior: "smooth", block: "nearest" })
  }

  dispatchMessage(message) {
    this.dispatch("message", { detail: { message } })
  }

  get returnMode() {
    if (this.hasReturnToggleTarget) return this.returnToggleTarget.checked

    return this.returnModeValue
  }

  get csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content
  }
}
