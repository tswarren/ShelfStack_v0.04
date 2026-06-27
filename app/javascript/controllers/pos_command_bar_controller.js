import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "returnToggle", "receiptPanel", "openRingPanel", "openRingReturnMode", "giftCardPanel", "balancePanel", "pickupPanel", "transactionDiscountPanel", "helpModal", "helpBody", "helpCloseButton"]
  static values = {
    routeUrl: String,
    addGiftCardUrl: String,
    returnMode: { type: Boolean, default: false }
  }

  connect() {
    this.boundHelpKeydown = this.helpKeydown.bind(this)
    this.focusInput()
    this.syncOpenRingReturnMode()
    this.applyLegacyModeDrawerFromUrl()
    this.applyCarryForwardFromUrl()
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundHelpKeydown)
    document.body.classList.remove("ss-pos-modal-open")
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
      case "disabled_command":
        this.dispatchMessage(data.message)
        break
      case "help":
        this.inputTarget.value = ""
        this.showHelpModal(data.payload || {})
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
      case "gift_card_sale_offer":
        this.showGiftCardPanel(data.payload)
        break
      case "return_drawer_offer":
        this.inputTarget.value = ""
        this.showReturnDrawerPanel(data.payload)
        break
      case "pickup_drawer_offer":
        this.inputTarget.value = ""
        this.showPickupDrawerPanel()
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
    this.showReturnDrawerPanel({ receipt_number: transactionNumber })
  }

  openModeDrawer(event) {
    event.preventDefault()
    this.setModeSwitchActive(event.currentTarget.dataset.mode)
    this.inputTarget.value = ""
    this.hidePanels()

    if (event.currentTarget.dataset.mode === "return") {
      this.showReturnDrawerPanel({})
    } else if (event.currentTarget.dataset.mode === "pickup") {
      this.showPickupDrawerPanel()
    }
  }

  setModeSwitchActive(mode) {
    this.element.querySelectorAll("[data-mode]").forEach((element) => {
      const active = element.dataset.mode === mode
      element.classList.toggle("ss-pos-mode-switch__btn--active", active)
      element.setAttribute("aria-current", active ? "page" : "false")
    })
  }

  showReturnDrawerPanel(payload = {}) {
    if (!this.hasReceiptPanelTarget) {
      this.dispatchMessage("Return workflow is not available.")
      return
    }

    this.setModeSwitchActive("return")
    this.receiptPanelTarget.hidden = false
    this.receiptPanelTarget.scrollIntoView({ behavior: "smooth", block: "nearest" })
    const receiptInput = this.receiptPanelTarget.querySelector("[data-pos-return-lookup-target='input']")
    if (receiptInput && payload.receipt_number) {
      receiptInput.value = payload.receipt_number
      receiptInput.dispatchEvent(new Event("change", { bubbles: true }))
      this.receiptPanelTarget.querySelector("[data-action*='pos-return-lookup#lookup']")?.click()
    } else if (receiptInput) {
      receiptInput.focus()
    }
  }

  showPickupDrawerPanel() {
    if (!this.hasPickupPanelTarget) {
      this.dispatchMessage("Pickup workflow is not available.")
      return
    }

    this.setModeSwitchActive("pickup")
    this.pickupPanelTarget.hidden = false
    this.pickupPanelTarget.scrollIntoView({ behavior: "smooth", block: "nearest" })
    const input = this.pickupPanelTarget.querySelector("[data-pos-pickup-panel-target='query']")
    input?.focus()
  }

  showOpenRingPanel(payload = {}) {
    if (!this.hasOpenRingPanelTarget) {
      this.dispatchMessage("Open-ring is not available.")
      return
    }

    this.syncOpenRingReturnMode()
    this.inputTarget.value = ""
    this.openRingPanelTarget.hidden = false
    this.openRingPanelTarget.scrollIntoView({ behavior: "smooth", block: "nearest" })

    const descriptionField = this.openRingPanelTarget.querySelector("[name='description']")
    const priceField = this.openRingPanelTarget.querySelector("[name='unit_price']")
    if (priceField && payload.amount_cents) {
      priceField.value = (payload.amount_cents / 100).toFixed(2)
    }
    if (descriptionField && payload.query) {
      descriptionField.value = payload.query
    }

    ;(descriptionField || priceField)?.focus()
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
    if (this.hasPickupPanelTarget) this.pickupPanelTarget.hidden = true
    this.closeHelpModal({ focusInput: false })
  }

  showHelpModal(payload) {
    if (!this.hasHelpModalTarget || !this.hasHelpBodyTarget) {
      this.dispatchMessage("Help is not available.")
      return
    }

    const commands = payload.commands || []
    this.helpBodyTarget.innerHTML = this.renderHelpCommands(commands, payload.category_labels)
    this.helpModalTarget.hidden = false
    document.body.classList.add("ss-pos-modal-open")
    document.addEventListener("keydown", this.boundHelpKeydown)
    this.helpCloseButtonTarget?.focus()
  }

  closeHelpModal(arg) {
    const options = arg instanceof Event ? {} : (arg || {})
    const focusInput = options.focusInput ?? true
    arg?.preventDefault?.()

    if (!this.hasHelpModalTarget || this.helpModalTarget.hidden) return

    this.helpModalTarget.hidden = true
    document.body.classList.remove("ss-pos-modal-open")
    document.removeEventListener("keydown", this.boundHelpKeydown)

    if (focusInput) this.focusInput()
  }

  helpKeydown(event) {
    if (event.key === "Escape") {
      this.closeHelpModal(event)
    }
  }

  renderHelpCommands(commands, categoryLabels = {}) {
    if (!commands.length) {
      return '<p class="ss-hint">No commands are available.</p>'
    }

    const groups = this.groupHelpCommands(commands, categoryLabels)
    const sections = groups.map((group) => {
      const rows = group.commands.map((command) => this.renderHelpRow(command)).join("")
      return `
        <section class="ss-pos-help-modal__group">
          <h3 class="ss-pos-help-modal__group-title">${this.escapeHtml(group.label)}</h3>
          <ul class="ss-pos-help-modal__list">${rows}</ul>
        </section>
      `
    }).join("")

    return `<div class="ss-pos-help-modal__grid">${sections}</div>`
  }

  groupHelpCommands(commands, categoryLabels) {
    const order = [ "sale", "adjustments", "payment", "register" ]
    const grouped = Object.fromEntries(order.map((key) => [ key, [] ]))

    commands.forEach((command) => {
      const category = command.category || "register"
      if (!grouped[category]) grouped[category] = []
      grouped[category].push(command)
    })

    return order
      .filter((key) => grouped[key]?.length)
      .map((key) => ({
        key,
        label: categoryLabels[key] || key,
        commands: grouped[key]
      }))
  }

  renderHelpRow(command) {
    const tokens = [ command.canonical, ...(command.aliases || []) ]
      .map((token) => this.escapeHtml(token.startsWith("/") ? token : `/${token}`))
    const statusClass = command.status === "available" ? "" : ` ss-pos-help-modal__item--${this.escapeHtml(command.status)}`

    return `
      <li class="ss-pos-help-modal__item${statusClass}">
        <span class="ss-pos-help-modal__tokens">${tokens.map((token) => `<code>${token}</code>`).join(" ")}</span>
        <span class="ss-pos-help-modal__description">${this.escapeHtml(command.description)}</span>
      </li>
    `
  }

  escapeHtml(value) {
    return String(value)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
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

    this.setModeSwitchActive("sale")
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

  closePickupPanel(event) {
    event?.preventDefault()
    if (!this.hasPickupPanelTarget) return

    this.setModeSwitchActive("sale")
    this.pickupPanelTarget.hidden = true
    const query = this.pickupPanelTarget.querySelector("[data-pos-pickup-panel-target='query']")
    if (query) query.value = ""
    const requestNumber = this.pickupPanelTarget.querySelector("[data-pos-pickup-panel-target='requestNumber']")
    if (requestNumber) requestNumber.value = ""
    const results = this.pickupPanelTarget.querySelector("[data-pos-pickup-panel-target='results']")
    if (results) results.innerHTML = ""
    const message = this.pickupPanelTarget.querySelector("[data-pos-pickup-panel-target='message']")
    if (message) message.textContent = ""
    this.focusInput()
  }

  openRingSubmitted(event) {
    if (event.detail.success) {
      this.closeOpenRingPanel()
    }
  }

  applyLegacyModeDrawerFromUrl() {
    const params = new URLSearchParams(window.location.search)
    const mode = params.get("mode")
    if (!mode || mode === "sale") return

    if (mode === "return") {
      this.showReturnDrawerPanel({})
    } else if (mode === "pickup") {
      this.showPickupDrawerPanel()
    } else {
      return
    }

    params.set("mode", "sale")
    const query = params.toString()
    const cleanUrl = query ? `${window.location.pathname}?${query}` : window.location.pathname
    window.history.replaceState({}, "", cleanUrl)
  }

  applyCarryForwardFromUrl() {
    const params = new URLSearchParams(window.location.search)
    const carryForward = params.get("carry_forward")
    if (!carryForward) return

    const amountCents = params.get("amount_cents")
    const payload = amountCents ? { amount_cents: parseInt(amountCents, 10) } : {}

    switch (carryForward) {
      case "open_ring":
        this.showOpenRingPanel(payload)
        break
      case "gift_card":
        this.showGiftCardPanel(payload)
        break
      case "return":
        this.showReturnDrawerPanel({
          receipt_number: params.get("receipt_number") || undefined
        })
        break
      case "pickup":
        this.showPickupDrawerPanel()
        break
      default:
        break
    }

    params.delete("carry_forward")
    params.delete("amount_cents")
    params.delete("receipt_number")
    const query = params.toString()
    const cleanUrl = query ? `${window.location.pathname}?${query}` : window.location.pathname
    window.history.replaceState({}, "", cleanUrl)
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
