import { Controller } from "@hotwired/stimulus"
import { closeOverlay, openOverlayById } from "shelfstack/overlay_shell"

export default class extends Controller {
  static targets = ["input", "returnToggle", "receiptPanel", "openRingPanel", "openRingReturnMode", "pickupPanel", "helpBody", "cashMovementForm", "cashMovementType", "cashMovementAmount", "cashMovementReason", "cashMovementSubmit", "drawerActionReason"]
  static values = {
    routeUrl: String,
    addGiftCardUrl: String,
    returnMode: { type: Boolean, default: false }
  }

  connect() {
    this.boundOpenTransactionDiscount = this.handleOpenTransactionDiscount.bind(this)
    this.boundOpenTaxExemption = this.handleOpenTaxExemption.bind(this)
    document.addEventListener("pos:open-transaction-discount-modal", this.boundOpenTransactionDiscount)
    document.addEventListener("pos:open-tax-exemption-modal", this.boundOpenTaxExemption)
    this.boundSessionDrawerClosed = this.handleSessionDrawerClosed.bind(this)
    document.addEventListener("drawer:closed", this.boundSessionDrawerClosed)
    this.focusInput()
    this.syncOpenRingReturnMode()
    requestAnimationFrame(() => {
      this.applyLegacyModeDrawerFromUrl()
      this.applyCarryForwardFromUrl()
    })
  }

  disconnect() {
    document.removeEventListener("pos:open-transaction-discount-modal", this.boundOpenTransactionDiscount)
    document.removeEventListener("pos:open-tax-exemption-modal", this.boundOpenTaxExemption)
    document.removeEventListener("drawer:closed", this.boundSessionDrawerClosed)
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

    this.runSlashCommand(input)
  }

  runSlashCommand(input) {
    if (!this.routeUrlValue) {
      this.dispatchMessage("Command routing is not available.")
      return
    }

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
        this.inputTarget.value = ""
        if (data.payload?.amount_cents) {
          this.addGiftCardSale(data.payload)
        } else {
          this.showGiftCardModal(data.payload)
        }
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
        this.inputTarget.value = ""
        this.showBalanceModal()
        break
      case "customer_lookup_offer":
        this.inputTarget.value = ""
        this.showCustomerLookupModal(data.payload || {})
        break
      case "tax_exemption_offer":
        this.inputTarget.value = ""
        this.showTaxExemptionModal()
        break
      case "line_discount_offer":
        if (data.payload?.line_id) {
          this.openLineDiscount(data.payload)
        } else {
          this.dispatchMessage(data.message || "No line available for discount.")
        }
        break
      case "transaction_discount_offer":
        this.showTransactionDiscountModal(data.payload || {})
        break
      case "settlement_offer":
        this.inputTarget.value = ""
        this.showSettlementModal(data.payload || {})
        break
      case "session_drawer_offer":
        this.inputTarget.value = ""
        this.showSessionDrawer(data.payload || {})
        break
      case "cash_movement_offer":
        this.inputTarget.value = ""
        this.showCashMovementModal(data.payload || {})
        break
      case "drawer_action_offer":
        this.inputTarget.value = ""
        this.showDrawerActionModal(data.payload || {})
        break
      case "reports_confirm_offer":
        this.inputTarget.value = ""
        this.confirmReportsNavigation(data.payload || {}, data.message)
        break
      case "suspend_transaction":
        this.inputTarget.value = ""
        this.suspendTransaction(data.payload || {})
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

  showSettlementModal(payload = {}) {
    const workspace = document.getElementById("pos_transaction_workspace")
    if (!workspace) {
      this.dispatchMessage("Settlement is not available.")
      return
    }

    const panel = this.application.getControllerForElementAndIdentifier(workspace, "pos-settlement-panel")
    if (!panel) {
      this.dispatchMessage("Settlement is not available.")
      return
    }

    panel.openWithOffer({
      tenderType: payload.tender_type || null,
      amountCents: payload.amount_cents ?? null,
      prefillRemaining: payload.prefill_remaining === true
    })
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

  showGiftCardModal(payload = {}) {
    if (!this.openWorkspaceModal("pos-gift-card-sale-modal")) {
      this.dispatchMessage("Gift card sales are not available.")
      return
    }

    const priceField = document.querySelector("#pos-gift-card-sale-modal [name='unit_price']")
    if (priceField) {
      priceField.value = payload.amount_cents ? (payload.amount_cents / 100).toFixed(2) : ""
      priceField.focus()
    }
  }

  showBalanceModal() {
    if (!this.openWorkspaceModal("pos-balance-inquiry-modal")) {
      this.dispatchMessage("Balance inquiry is not available.")
    }
  }

  showCustomerLookupModal(payload = {}) {
    if (!this.openWorkspaceModal("pos-customer-lookup-modal")) {
      this.dispatchMessage("Customer lookup is not available.")
      return
    }

    const query = payload.query?.trim()
    if (!query) return

    const input = document.querySelector("#pos-customer-lookup-modal [data-customer-lookup-target='lookupInput']")
    if (!input) return

    input.value = query
    input.dispatchEvent(new KeyboardEvent("keydown", { key: "Enter", bubbles: true }))
  }

  showTaxExemptionModal(payload = {}) {
    if (!this.openWorkspaceModal("pos-tax-exemption-modal")) {
      this.dispatchMessage("Tax exemption is not available.")
      return
    }

    this.inputTarget.value = ""
    requestAnimationFrame(() => this.focusTaxExemptionModal(payload))
  }

  handleOpenTaxExemption(event) {
    this.showTaxExemptionModal(event.detail || {})
  }

  focusTaxExemptionModal(payload = {}) {
    const modal = document.getElementById("pos-tax-exemption-modal")
    if (!modal) return

    if (payload.focus === "firstInvalid") {
      const invalid = modal.querySelector(".ss-field--invalid input, .ss-field--invalid select, .ss-field--invalid textarea")
      if (invalid) {
        invalid.focus()
        return
      }
    }

    modal.querySelector("[name='tax_exception_reason_id']")?.focus()
  }

  closeTaxExemptionModal(arg) {
    const options = arg instanceof Event ? {} : (arg || {})
    const focusInput = options.focusInput ?? true
    arg?.preventDefault?.()

    this.closeWorkspaceModal("pos-tax-exemption-modal")
    if (focusInput) this.focusInput()
  }

  handleOpenTransactionDiscount(event) {
    this.showTransactionDiscountModal(event.detail || {})
  }

  showTransactionDiscountModal(payload = {}) {
    if (!this.openWorkspaceModal("pos-transaction-discount-modal")) {
      this.dispatchMessage("Transaction discount is not available.")
      return
    }

    this.inputTarget.value = ""
    requestAnimationFrame(() => {
      this.prefillTransactionDiscountModal(payload)
      this.focusTransactionDiscountModal(payload)
    })
  }

  prefillTransactionDiscountModal(payload = {}) {
    const modal = document.getElementById("pos-transaction-discount-modal")
    if (!modal) return

    const controller = this.discountInputControllerFor(modal)
    controller?.prefill({
      discountType: payload.discount_type,
      discountValue: payload.discount_value
    })
  }

  discountInputControllerFor(container) {
    const element = container.querySelector("[data-controller~='pos-discount-input']")
    if (!element) return null

    return this.application.getControllerForElementAndIdentifier(element, "pos-discount-input")
  }

  focusTransactionDiscountModal(payload = {}) {
    const modal = document.getElementById("pos-transaction-discount-modal")
    if (!modal) return

    const reason = modal.querySelector("[name='discount_reason_id']")
    const value = modal.querySelector(".ss-pos-discount-input")

    if (payload.focus === "amount" && value) {
      value.focus()
      value.select()
      return
    }

    if (payload.focus === "firstInvalid") {
      const invalid = modal.querySelector(".ss-field--invalid input, .ss-field--invalid select, .ss-field--invalid textarea")
      if (invalid) {
        invalid.focus()
        invalid.select?.()
        return
      }
    }

    reason?.focus()
  }

  closeTransactionDiscountModal(arg) {
    const options = arg instanceof Event ? {} : (arg || {})
    const focusInput = options.focusInput ?? true
    arg?.preventDefault?.()

    this.closeWorkspaceModal("pos-transaction-discount-modal")
    if (focusInput) this.focusInput()
  }

  transactionDiscountSubmitted(event) {
    if (event.detail?.success === false) return

    this.closeTransactionDiscountModal({ focusInput: true })
  }

  openWorkspaceModal(modalId) {
    const modal = document.getElementById(modalId)
    if (!modal) return false

    const controller = this.application.getControllerForElementAndIdentifier(modal, "modal")
    if (!controller) return false

    controller.open()
    return true
  }

  closeWorkspaceModal(modalId) {
    const modal = document.getElementById(modalId)
    if (!modal) return

    const controller = this.application.getControllerForElementAndIdentifier(modal, "modal")
    controller?.close()
  }

  modalClosed(event) {
    if (!event.target?.classList?.contains("ss-modal")) return

    if (event.target.id === "pos-balance-inquiry-modal") {
      this.resetBalanceInquiry()
      this.inputTarget.value = ""
    }

    requestAnimationFrame(() => this.focusInput())
  }

  showSessionDrawer(payload = {}) {
    const opened = openOverlayById(this.application, "drawer", "pos-session-drawer", this.inputTarget)
    if (!opened) {
      this.dispatchMessage("Session summary is not available.")
      return
    }

    requestAnimationFrame(() => this.focusSessionDrawerSection(payload.focus || "session"))
  }

  openSessionDrawer(event) {
    event?.preventDefault()
    this.showSessionDrawer({ focus: "session" })
  }

  openHeldDrawer(event) {
    event?.preventDefault()
    this.showSessionDrawer({ focus: "held" })
  }

  openRingQuickAction(event) {
    event?.preventDefault()
    this.showOpenRingPanel({})
  }

  openGiftCardQuickAction(event) {
    event?.preventDefault()
    this.showGiftCardModal({})
  }

  openCashIn(event) {
    event?.preventDefault()
    this.showCashMovementModal({ movement_type: "paid_in" })
  }

  openCashOut(event) {
    event?.preventDefault()
    this.showCashMovementModal({ movement_type: "paid_out" })
  }

  openDrawerQuickAction(event) {
    event?.preventDefault()
    this.showDrawerActionModal({})
  }

  runCloseRegister(event) {
    event?.preventDefault()
    this.runSlashCommand("/close")
  }

  runReports(event) {
    event?.preventDefault()
    this.runSlashCommand("/reports")
  }

  focusSessionDrawerSection(focus) {
    const sectionId = focus === "held" ? "pos-session-drawer-held" : "pos-session-drawer-summary"
    const section = document.getElementById(sectionId)
    section?.scrollIntoView({ behavior: "smooth", block: "start" })

    if (focus === "held") {
      section?.querySelector("a.ss-btn, button.ss-btn")?.focus()
    }
  }

  closeSessionDrawer() {
    const drawer = document.getElementById("pos-session-drawer")
    if (!drawer || drawer.hidden) return

    const controller = this.application.getControllerForElementAndIdentifier(drawer, "drawer")
    if (controller?._overlayShell) closeOverlay(controller, { force: true })
  }

  handleSessionDrawerClosed(event) {
    if (event.target?.id !== "pos-session-drawer") return

    this.focusInput()
  }

  showCashMovementModal(payload = {}) {
    const movementType = payload.movement_type || "paid_in"
    const title = movementType === "paid_out" ? "Cash out" : "Cash in"
    const titleEl = document.getElementById("pos-cash-movement-modal-title")
    if (titleEl) titleEl.textContent = title

    if (!this.openWorkspaceModal("pos-cash-movement-modal")) {
      this.dispatchMessage("Cash movements are not available.")
      return
    }

    if (this.hasCashMovementTypeTarget) {
      this.cashMovementTypeTarget.value = movementType
    }
    if (this.hasCashMovementSubmitTarget) {
      this.cashMovementSubmitTarget.value = movementType === "paid_out" ? "Record cash out" : "Record cash in"
    }
    if (this.hasCashMovementAmountTarget) {
      this.cashMovementAmountTarget.value = payload.amount_cents ? (payload.amount_cents / 100).toFixed(2) : ""
    }
    if (this.hasCashMovementReasonTarget) {
      this.cashMovementReasonTarget.value = ""
    }

    this.cashMovementAmountTarget?.focus()
  }

  closeCashMovementModal(arg) {
    const options = arg instanceof Event ? {} : (arg || {})
    const focusInput = options.focusInput ?? true
    arg?.preventDefault?.()

    this.closeWorkspaceModal("pos-cash-movement-modal")
    if (focusInput) this.focusInput()
  }

  cashMovementSubmitted(event) {
    if (event.detail?.success === false) return

    this.closeCashMovementModal()
  }

  showDrawerActionModal(payload = {}) {
    if (this.hasDrawerActionReasonTarget) {
      if (payload.reason) {
        this.drawerActionReasonTarget.textContent = `Note: ${payload.reason}`
        this.drawerActionReasonTarget.hidden = false
      } else {
        this.drawerActionReasonTarget.textContent = ""
        this.drawerActionReasonTarget.hidden = true
      }
    }

    if (!this.openWorkspaceModal("pos-drawer-action-modal")) {
      this.dispatchMessage("Cash drawer action is not available.")
    }
  }

  closeDrawerActionModal(arg) {
    const options = arg instanceof Event ? {} : (arg || {})
    const focusInput = options.focusInput ?? true
    arg?.preventDefault?.()

    this.closeWorkspaceModal("pos-drawer-action-modal")
    if (focusInput) this.focusInput()
  }

  confirmReportsNavigation(payload, message) {
    const url = payload.url
    if (!url) return

    if (window.confirm(message || "Leave the current transaction and open Reports?")) {
      window.location.href = url
    } else {
      this.focusInput()
    }
  }

  suspendTransaction(payload) {
    const url = payload.url
    if (!url) {
      this.dispatchMessage("Unable to hold transaction.")
      return
    }

    fetch(url, {
      method: "PATCH",
      headers: {
        "X-CSRF-Token": this.csrfToken,
        Accept: "text/html"
      },
      redirect: "follow"
    })
      .then((response) => {
        if (response.ok || response.redirected) {
          window.location.href = payload.redirect_url || response.url
          return
        }

        this.dispatchMessage("Unable to hold transaction.")
      })
      .catch(() => this.dispatchMessage("Unable to hold transaction."))
  }

  closeBalancePanel(event) {
    event?.preventDefault()
    this.resetBalanceInquiry()
    this.closeWorkspaceModal("pos-balance-inquiry-modal")
    this.inputTarget.value = ""
    this.focusInput()
  }

  resetBalanceInquiry() {
    const panel = document.getElementById("pos-balance-inquiry-modal")
    if (!panel) return

    const input = panel.querySelector("[data-pos-balance-inquiry-target='input']")
    if (input) input.value = ""
    const status = panel.querySelector("[data-pos-balance-inquiry-target='status']")
    if (status) {
      status.textContent = ""
      status.hidden = true
    }
    const result = panel.querySelector("[data-pos-balance-inquiry-target='result']")
    if (result) {
      result.innerHTML = ""
      result.hidden = true
    }
  }

  closeGiftCardPanel(arg) {
    const options = arg instanceof Event ? {} : (arg || {})
    const focusInput = options.focusInput ?? true
    arg?.preventDefault?.()

    this.closeWorkspaceModal("pos-gift-card-sale-modal")
    document.querySelector("#pos-gift-card-sale-modal form")?.reset()
    if (focusInput) this.focusInput()
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
        requestAnimationFrame(() => this.focusInput())
      })
      .catch(() => this.dispatchMessage("Unable to add gift card sale."))
  }

  giftCardSubmitted(event) {
    if (event.detail.success) {
      this.closeWorkspaceModal("pos-gift-card-sale-modal")
      document.querySelector("#pos-gift-card-sale-modal form")?.reset()
      requestAnimationFrame(() => this.focusInput())
    }
  }

  taxExemptionSubmitted(event) {
    if (event.detail?.success === false) return

    this.closeTaxExemptionModal({ focusInput: true })
  }

  hidePanels() {
    if (this.hasReceiptPanelTarget) this.receiptPanelTarget.hidden = true
    if (this.hasOpenRingPanelTarget) this.openRingPanelTarget.hidden = true
    if (this.hasPickupPanelTarget) this.pickupPanelTarget.hidden = true
    this.closeSessionDrawer()
    this.closeCashMovementModal({ focusInput: false })
    this.closeDrawerActionModal({ focusInput: false })
    this.closeWorkspaceModal("pos-help-modal")
    this.resetBalanceInquiry()
    this.closeWorkspaceModal("pos-balance-inquiry-modal")
    this.closeWorkspaceModal("pos-gift-card-sale-modal")
    this.closeWorkspaceModal("pos-customer-lookup-modal")
    this.closeWorkspaceModal("pos-tax-exemption-modal")
    this.closeWorkspaceModal("pos-transaction-discount-modal")
  }

  showHelpModal(payload) {
    if (!this.hasHelpBodyTarget) {
      this.dispatchMessage("Help is not available.")
      return
    }

    const commands = payload.commands || []
    this.helpBodyTarget.innerHTML = this.renderHelpCommands(commands, payload.category_labels)
    if (!this.openWorkspaceModal("pos-help-modal")) {
      this.dispatchMessage("Help is not available.")
    }
  }

  closeHelpModal(arg) {
    const options = arg instanceof Event ? {} : (arg || {})
    const focusInput = options.focusInput ?? true
    arg?.preventDefault?.()

    this.closeWorkspaceModal("pos-help-modal")
    if (focusInput) this.focusInput()
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
        if (payload.amount_cents) {
          this.addGiftCardSale(payload)
        } else {
          this.showGiftCardModal(payload)
        }
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

  openLineDiscount(payload = {}) {
    const lineId = payload.line_id ?? payload.lineId
    if (!lineId) return

    this.inputTarget.value = ""
    document.dispatchEvent(new CustomEvent("pos:open-line-discount", {
      detail: {
        lineId: String(lineId),
        discount_type: payload.discount_type,
        discount_value: payload.discount_value,
        focus: payload.focus || (payload.discount_value ? "amount" : null)
      }
    }))
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
