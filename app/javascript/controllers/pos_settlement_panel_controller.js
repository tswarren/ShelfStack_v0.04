import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "modal",
    "rows",
    "draftRows",
    "activeDetail",
    "typeSelector",
    "amountDue",
    "tenderedTotal",
    "readyComplete",
    "emptyRow",
    "cardTemplate",
    "checkTemplate",
    "cashTemplate",
    "storeCreditTemplate",
    "giftCardTemplate",
    "storedValueTemplate",
    "destroyField",
    "amountField",
    "lookupCodeField",
    "lookupStatus",
    "remainingBalance",
    "changeDue",
    "rowSummaryAmount"
  ]

  static values = {
    totalCents: Number,
    refund: Boolean,
    lookupUrl: String,
    syncUrl: String
  }

  connect() {
    this.boundKeydown = this.keydown.bind(this)
    this.modalWasOpen = false
    this.visibleRows().forEach((row) => {
      this.syncRowLayout(row)
      this.updateRowSummary(row)
    })
    this.update()
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundKeydown)
  }

  open(event, { skipInitialFocus = false } = {}) {
    event?.preventDefault()
    if (!this.hasModalTarget) return

    this.modalTarget.hidden = false
    document.body.classList.add("ss-pos-modal-open")
    document.addEventListener("keydown", this.boundKeydown)
    this.syncTotal()
    this.update()
    this.element.dispatchEvent(new CustomEvent("pos:settlement-opened", { bubbles: true }))

    if (!skipInitialFocus) {
      this.focusModalInitial()
    }
  }

  focusModalInitial() {
    this.focusModalEntry(() => {
      if (this.hasActiveDraft()) {
        this.focusRowEntry(this.activeDraftRow())
        return
      }

      const rows = this.visibleRows()
      const emptyAmountRow = rows.find((row) => !this.rowHasAmount(row))
      if (emptyAmountRow) {
        this.focusRowEntry(emptyAmountRow)
        return
      }

      if (this.readyToComplete()) {
        this.completeButton()?.focus()
        return
      }

      if (this.hasTypeSelectorTarget) {
        this.typeSelectorTarget.querySelector("button")?.focus()
        return
      }

      this.completeButton()?.focus()
    })
  }

  focusModalEntry(focusFn) {
    requestAnimationFrame(() => {
      document.querySelector("[data-pos-command-bar-target='input']")?.blur()
      focusFn()
    })
  }

  close(event) {
    event?.preventDefault()
    if (!this.hasModalTarget || this.modalTarget.hidden) return

    this.modalTarget.hidden = true
    document.body.classList.remove("ss-pos-modal-open")
    document.removeEventListener("keydown", this.boundKeydown)
    requestAnimationFrame(() => this.focusCommandInput())
  }

  focusCommandInput() {
    document.querySelector("[data-pos-command-bar-target='input']")?.focus()
  }

  keydown(event) {
    if (!this.hasModalTarget || this.modalTarget.hidden) return

    if (event.key === "Escape") {
      event.preventDefault()
      event.stopPropagation()
      if (this.hasActiveDraft()) {
        this.cancelActiveDetail()
      } else if (this.hasExpandedSavedRow()) {
        this.collapseExpandedSavedRows()
      } else {
        this.close()
      }
      return
    }

    if (event.key === "Enter" && !this.isSubmitControl(event.target) && !this.isActionControl(event.target)) {
      if (this.hasActiveDraft()) {
        event.preventDefault()
        event.stopPropagation()
        this.saveActiveDetail()
        return
      }

      if (this.readyToComplete()) {
        event.preventDefault()
        this.focusCompleteButton()?.click()
      }
      return
    }

    if (this.isTypingInField(event.target) && !this.isHotkeySelection(event)) return

    const hotkey = this.hotkeyForEvent(event)
    if (hotkey) {
      event.preventDefault()
      this.selectTenderTypeByKey(hotkey)
    }
  }

  hasExpandedSavedRow() {
    return this.visibleRows().some((row) => row.dataset.collapsed === "false")
  }

  collapseExpandedSavedRows() {
    this.visibleRows().forEach((row) => {
      if (row.dataset.collapsed !== "false") return

      row.dataset.collapsed = "true"
      this.syncRowLayout(row)
      this.updateRowSummary(row)
    })
    this.typeSelectorTarget?.querySelector("button")?.focus()
  }

  isTypingInField(target) {
    if (!(target instanceof HTMLElement)) return false

    const tag = target.tagName
    return tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT" || target.isContentEditable
  }

  isSubmitControl(target) {
    return target instanceof HTMLElement && target.closest("button[type='submit'], input[type='submit']")
  }

  isActionControl(target) {
    return target instanceof HTMLElement && target.closest("button, a, [role='button']")
  }

  isHotkeySelection(event) {
    return !this.isTypingInField(event.target) && ["1", "2", "3", "4"].includes(event.key)
  }

  hotkeyForEvent(event) {
    if (this.isTypingInField(event.target)) return null
    if (!["1", "2", "3", "4"].includes(event.key)) return null

    const button = this.typeSelectorTarget?.querySelector(`[data-hotkey='${event.key}']`)
    return button ? event.key : null
  }

  selectTenderType(event) {
    event?.preventDefault()
    const tenderType = event.currentTarget.dataset.tenderType
    if (!tenderType) return

    this.openDraftForType(tenderType, { prefillRemaining: true })
  }

  selectTenderTypeByKey(key) {
    const button = this.typeSelectorTarget?.querySelector(`[data-hotkey='${key}']`)
    button?.click()
  }

  openDraftForType(tenderType, { amountCents = null, prefillRemaining = false } = {}) {
    const templateFor = {
      cash: this.cashTemplateTarget,
      card: this.cardTemplateTarget,
      check: this.checkTemplateTarget,
      store_credit: this.storeCreditTemplateTarget,
      gift_card: this.giftCardTemplateTarget,
      stored_value: this.storedValueTemplateTarget
    }
    const template = templateFor[tenderType]
    if (!template) return

    this.syncTotal()
    this.clearDraftRow()
    const row = this.appendDraftRow(template, tenderType)
    if (!row) return

    if (amountCents != null) {
      this.setRowAmountCents(row, amountCents)
    } else if (this.shouldPrefillRemainingForRow(tenderType, row, prefillRemaining)) {
      this.fillRemainingForRow(row, tenderType)
    }

    if (this.hasActiveDetailTarget) {
      this.activeDetailTarget.hidden = false
    }

    this.highlightActiveType(tenderType)
    this.update()
    this.focusModalEntry(() => {
      this.focusRowEntry(row)
    })
  }

  appendDraftRow(template, tenderType) {
    if (!this.hasDraftRowsTarget) return null

    const index = this.nextSettlementIndex()
    const fragment = template.content.cloneNode(true)
    const row = fragment.querySelector("[data-settlement-row]")
    if (!row) return null

    fragment.querySelectorAll("[name]").forEach((field) => {
      field.name = field.name.replace("[TEMPLATE]", `[${index}]`)
    })

    row.dataset.rowId = ""
    row.dataset.settlementIndex = String(index)
    row.dataset.settlementType = tenderType
    row.dataset.draft = "true"
    row.removeAttribute("data-destroyed")
    row.dataset.collapsed = "false"
    this.draftRowsTarget.appendChild(fragment)
    this.syncRowLayout(row)
    return row
  }

  clearDraftRow() {
    if (!this.hasDraftRowsTarget) return

    this.draftRowsTarget.innerHTML = ""
    if (this.hasActiveDetailTarget) {
      this.activeDetailTarget.hidden = true
    }
    this.clearActiveTypeHighlight()
  }

  cancelActiveDetail(event) {
    event?.preventDefault()
    this.clearDraftRow()
    this.update()
    this.typeSelectorTarget?.querySelector("button")?.focus()
  }

  async saveActiveDetail(event) {
    event?.preventDefault()
    const draftRow = this.activeDraftRow()
    if (!draftRow) return

    this.normalizeDraftRowTenderType(draftRow)

    if (!this.rowHasAmount(draftRow) &&
        !this.isStoredValueTenderType(draftRow.dataset.settlementType)) {
      this.focusRowEntry(draftRow)
      return
    }

    if (draftRow.dataset.settlementType === "stored_value") {
      this.focusRowEntry(draftRow)
      return
    }

    if (this.isStoredValueTenderType(draftRow.dataset.settlementType) &&
        !draftRow.querySelector("[name*='[stored_value_account_id]']")?.value) {
      this.focusRowEntry(draftRow)
      return
    }

    this.clampStoredValueAmount(draftRow)
    await this.syncSettlementRows(draftRow)
  }

  async syncSettlementRows(draftRow = null) {
    const syncUrl = this.syncUrlValue || this.modalTarget?.dataset?.posSettlementPanelSyncUrlValue
    if (!syncUrl) return false

    this.modalWasOpen = !this.modalTarget.hidden
    const body = this.buildSyncFormData(draftRow)

    try {
      const response = await fetch(syncUrl, {
        method: "PATCH",
        headers: {
          Accept: "text/vnd.turbo-stream.html",
          "X-CSRF-Token": this.csrfToken
        },
        credentials: "same-origin",
        body
      })

      const html = await response.text()
      if (html) {
        window.Turbo.renderStreamMessage(html)
      }

      if (response.ok && this.modalWasOpen) {
        requestAnimationFrame(() => this.open())
      }

      return response.ok
    } catch (_error) {
      return false
    }
  }

  buildSyncFormData(draftRow = null) {
    const body = new FormData()
    const form = this.modalTarget.querySelector("form")

    this.allSavedRows().forEach((row) => {
      this.appendRowToFormData(body, row)
    })

    if (draftRow) {
      this.appendRowToFormData(body, draftRow)
    }

    if (form) {
      const authorizationId = form.querySelector("[name='pos_authorization_id']")?.value
      if (authorizationId) body.append("pos_authorization_id", authorizationId)
      const confirmInactive = form.querySelector("[name='confirm_inactive']")
      if (confirmInactive && !confirmInactive.disabled) body.append("confirm_inactive", "1")
    }

    body.append("reopen_settlement_modal", "1")
    return body
  }

  allSavedRows() {
    if (!this.hasRowsTarget) return []

    return Array.from(this.rowsTarget.querySelectorAll("[data-settlement-row]"))
  }

  appendRowToFormData(body, row) {
    if (row.dataset.destroyed === "true" || row.hidden) {
      const index = row.dataset.settlementIndex
      if (!index) return

      body.append(`settlements[${index}][id]`, row.dataset.rowId || "")
      body.append(`settlements[${index}][_destroy]`, "1")
      body.append(`settlements[${index}][tender_type]`, row.dataset.settlementType || "")
      return
    }

    this.appendRowFields(body, row)
  }

  appendRowFields(body, row) {
    row.querySelectorAll("input[name], select[name], textarea[name]").forEach((field) => {
      if (field.type === "checkbox" && !field.checked) return
      body.append(field.name, field.value)
    })
  }

  hasActiveDraft() {
    return this.activeDraftRow() != null
  }

  activeDraftRow() {
    if (!this.hasDraftRowsTarget) return null

    return this.draftRowsTarget.querySelector("[data-settlement-row]")
  }

  highlightActiveType(tenderType) {
    if (!this.hasTypeSelectorTarget) return

    this.typeSelectorTarget.querySelectorAll("[data-tender-type]").forEach((button) => {
      button.classList.toggle("ss-pos-tender-workspace__type-btn--active", button.dataset.tenderType === tenderType)
    })
  }

  clearActiveTypeHighlight() {
    if (!this.hasTypeSelectorTarget) return

    this.typeSelectorTarget.querySelectorAll("[data-tender-type]").forEach((button) => {
      button.classList.remove("ss-pos-tender-workspace__type-btn--active")
    })
  }

  readyToComplete() {
    const button = this.completeButton()
    return button && !button.disabled
  }

  focusCompleteButton() {
    const button = this.completeButton()
    button?.focus()
    return button
  }

  completeButton() {
    return this.modalTarget?.querySelector("[data-pos-transaction-edit-target='completeButton']")
  }

  get csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content
  }

  syncTotal() {
    const totalEl = this.element.querySelector("[data-pos-transaction-edit-target='total']")
    if (!totalEl) return

    const cents = parseInt(totalEl.dataset.totalCents, 10)
    if (Number.isNaN(cents)) return

    this.totalCentsValue = cents
    if (this.hasRefundValue) {
      this.refundValue = cents < 0
    }
    this.update()
    this.element.dispatchEvent(new CustomEvent("pos:settlement-updated", { bubbles: true }))
  }

  fillCashFromReadiness() {
    this.openWithOffer({ tenderType: "cash", prefillRemaining: true })
  }

  openWithOffer({ tenderType = null, amountCents = null, prefillRemaining = null } = {}) {
    this.open(null, { skipInitialFocus: tenderType != null })

    if (!tenderType) {
      this.focusModalInitial()
      return
    }

    const inferredPrefill =
      prefillRemaining ??
      (amountCents == null && !this.isStoredValueTenderType(tenderType))

    this.openDraftForType(tenderType, {
      amountCents,
      prefillRemaining: amountCents == null && inferredPrefill
    })
  }

  update() {
    this.visibleRows().forEach((row) => {
      this.clampStoredValueAmount(row)
      this.updateRowSummary(row)
    })
    this.updateHints()
    this.dispatchUpdate()
  }

  dispatchUpdate() {
    this.element.dispatchEvent(new CustomEvent("pos:settlement-updated", { bubbles: true }))
  }

  addCard(event) {
    event.preventDefault()
    this.appendRow(this.cardTemplateTarget)
  }

  addCheck(event) {
    event.preventDefault()
    this.appendRow(this.checkTemplateTarget)
  }

  addCash(event) {
    event.preventDefault()
    const existing = this.rowsTarget.querySelector("[data-settlement-type='cash']:not([data-destroyed='true'])")
    if (existing && !existing.hidden) {
      this.expandRowElement(existing)
      this.focusRowEntry(existing)
      return
    }

    this.appendRow(this.cashTemplateTarget)
  }

  addStoreCredit(event) {
    event.preventDefault()
    this.appendRow(this.storeCreditTemplateTarget)
  }

  addGiftCard(event) {
    event.preventDefault()
    this.appendRow(this.giftCardTemplateTarget)
  }

  async lookupStoredValue(event) {
    const row = event.currentTarget.closest("[data-settlement-row]")
    if (!row || !this.hasLookupUrlValue) return

    const codeField = row.querySelector("[name*='[lookup_code]']")
    const code = codeField?.value?.trim()
    if (!code) return

    const tenderType = row.dataset.settlementType
    const statusEl = row.querySelector("[data-pos-settlement-panel-target='lookupStatus']")
    const url = new URL(this.lookupUrlValue, window.location.origin)
    url.searchParams.set("code", code)
    url.searchParams.set("tender_type", tenderType)

    try {
      const response = await fetch(url.toString(), {
        headers: { Accept: "application/json" },
        credentials: "same-origin"
      })
      const payload = await response.json()
      if (!response.ok) {
        if (statusEl) statusEl.textContent = payload.message || "Lookup failed."
        return
      }

      this.applyResolvedStoredValueType(row, payload)

      const accountField = row.querySelector("[name*='[stored_value_account_id]']")
      const identifierField = row.querySelector("[name*='[stored_value_identifier_id]']")
      if (accountField) accountField.value = payload.account_id
      if (identifierField) identifierField.value = payload.identifier_id
      row.dataset.storedValueBalanceCents = String(payload.current_balance_cents)

      const resolvedType = row.dataset.settlementType
      const typeLabel = payload.resolved_tender_type_label || this.storedValueTypeLabel(resolvedType)

      if (statusEl) {
        statusEl.textContent = `${typeLabel} · ${payload.display_value_masked} · Balance ${this.formatMoney(payload.current_balance_cents)}`
      }

      if (this.rowAmountCents(row) === 0) {
        this.fillRemainingForRow(row, resolvedType)
      } else {
        this.clampStoredValueAmount(row)
      }
      this.updateRowSummary(row)
      this.updateHints()
      this.dispatchUpdate()
      this.focusStoredValueAmount(row)
    } catch (_error) {
      if (statusEl) statusEl.textContent = "Lookup failed."
    }
  }

  appendRow(template) {
    this.hideEmptyRow()
    const index = this.nextSettlementIndex()
    const fragment = template.content.cloneNode(true)
    const row = fragment.querySelector("[data-settlement-row]")
    if (!row) return

    fragment.querySelectorAll("[name]").forEach((field) => {
      field.name = field.name.replace("[TEMPLATE]", `[${index}]`)
    })

    row.dataset.rowId = ""
    row.dataset.settlementIndex = String(index)
    row.removeAttribute("data-destroyed")
    row.dataset.collapsed = "false"
    this.rowsTarget.appendChild(fragment)
    this.syncRowLayout(row)
    this.update()
    this.focusRowEntry(row)
  }

  removeRow(event) {
    event.preventDefault()
    const row = event.currentTarget.closest("[data-settlement-row]")
    if (!row) return

    const destroyField = row.querySelector("[data-pos-settlement-panel-target='destroyField']")
    const persisted = Boolean(row.dataset.rowId)

    if (persisted) {
      if (destroyField) destroyField.value = "1"
      row.dataset.destroyed = "true"
      row.hidden = true
    } else {
      row.remove()
    }

    if (this.visibleRows().length === 0) {
      this.showEmptyRow()
    }

    this.update()

    if (persisted) {
      this.syncSettlementRows()
    }
  }

  fillRemaining(event) {
    event.preventDefault()
    const tenderType = event.currentTarget.dataset.tenderType
    const row = event.currentTarget.closest("[data-settlement-row]")
    if (!tenderType || !row) return

    this.fillRemainingForRow(row, tenderType)
    this.update()
  }

  fillRemainingForRow(row, tenderType) {
    const totalCents = this.totalCentsValue
    if (Number.isNaN(totalCents)) return

    let otherTotal = 0
    this.rowsForTotals().forEach((visibleRow) => {
      if (visibleRow === row) return

      otherTotal += this.rowAmountCents(visibleRow)
    })

    let displayCents
    if (totalCents < 0) {
      displayCents = Math.abs(totalCents) - otherTotal
    } else {
      displayCents = totalCents - otherTotal
      if (tenderType !== "cash") {
        displayCents = Math.max(0, displayCents)
      }
    }

    displayCents = Math.max(0, displayCents)

    if (tenderType === "store_credit" || tenderType === "gift_card" || tenderType === "stored_value") {
      displayCents = this.cappedStoredValueAmountCents(row, displayCents)
    }

    this.setRowAmountCents(row, displayCents)
    this.collapseRowIfReady(row)
  }

  rowFocusOut(event) {
    const row = event.target.closest("[data-settlement-row]")
    if (!row || row.dataset.destroyed === "true") return

    requestAnimationFrame(() => {
      if (row.contains(document.activeElement)) return
      this.collapseRowIfReady(row)
    })
  }

  expandRow(event) {
    event.preventDefault()
    const row = event.currentTarget.closest("[data-settlement-row]")
    if (!row) return

    this.expandRowElement(row)
    this.focusRowEntry(row)
  }

  expandRowElement(row) {
    row.dataset.collapsed = "false"
    this.syncRowLayout(row)
  }

  collapseRowIfReady(row) {
    if (row.dataset.draft === "true") return
    if (!this.rowHasAmount(row)) return

    row.dataset.collapsed = "true"
    this.syncRowLayout(row)
    this.updateRowSummary(row)
  }

  syncRowLayout(row) {
    const labelCell = row.querySelector(".ss-pos-settlement-row__label-cell")
    const amountCell = row.querySelector(".ss-pos-settlement-row__amount-cell")
    if (!labelCell || !amountCell) return

    const collapsed = row.dataset.collapsed === "true"
    labelCell.colSpan = collapsed ? 1 : 2
    amountCell.hidden = !collapsed
  }

  rowHasAmount(row) {
    return this.rowAmountCents(row) > 0
  }

  updateRowSummary(row) {
    const { label, amount } = this.rowSummaryParts(row)
    const labelTarget = row.querySelector("[data-pos-settlement-panel-target='rowSummaryLabel']")
    const amountTarget = row.querySelector("[data-pos-settlement-panel-target='rowSummaryAmount']")

    if (labelTarget) labelTarget.textContent = label
    if (amountTarget) amountTarget.textContent = amount
  }

  rowSummaryParts(row) {
    const amountCents = this.rowAmountCents(row)
    const amount = this.formatMoney(amountCents)
    const tenderType = row.dataset.settlementType

    if (tenderType === "cash") {
      const label = this.refundValue ? "Cash refund" : "Cash"
      return { label, amount }
    }

    if (tenderType === "card") {
      const brandField = row.querySelector("[name*='[card_brand]']")
      const brand = brandField?.selectedOptions?.[0]?.text || "Card"
      const lastFour = row.querySelector("[name*='[card_last_four]']")?.value
      const label = lastFour ? `Card – ${brand} ${lastFour}` : `Card – ${brand}`
      return { label, amount }
    }

    if (tenderType === "check") {
      const checkNumber = row.querySelector("[name*='[check_number]']")?.value
      const label = checkNumber ? `Check #${checkNumber}` : "Check"
      return { label, amount }
    }

    if (tenderType === "store_credit" || tenderType === "gift_card" || tenderType === "stored_value") {
      const base = tenderType === "gift_card" ? "Gift card" : tenderType === "store_credit" ? "Store credit" : "Stored value"
      const status = row.querySelector("[data-pos-settlement-panel-target='lookupStatus']")?.textContent
      const label = status ? `${base} ${status.split("·")[0].trim()}` : base
      return { label, amount }
    }

    return { label: tenderType, amount }
  }

  visibleRows() {
    return this.allSavedRows().filter((row) => row.dataset.destroyed !== "true" && !row.hidden)
  }

  rowsForTotals() {
    const rows = [ ...this.visibleRows() ]
    const draftRow = this.activeDraftRow()
    if (draftRow) rows.push(draftRow)

    return rows
  }

  rowAmountCents(row) {
    const field = row.querySelector("[data-settlement-amount]")
    if (!field) return 0

    return Math.round(parseFloat(field.value || "0") * 100)
  }

  setRowAmountCents(row, cents) {
    const field = row.querySelector("[data-settlement-amount]")
    if (field) {
      field.value = (cents / 100).toFixed(2)
    }
  }

  updateHints() {
    const totalCents = this.totalCentsValue
    if (Number.isNaN(totalCents)) return

    let nonCashCents = 0
    let cashTenderedCents = 0

    this.visibleRows().forEach((row) => {
      const cents = this.rowAmountCents(row)
      if (row.dataset.settlementType === "cash") {
        cashTenderedCents = cents
      } else {
        nonCashCents += cents
      }
    })

    const draftRow = this.activeDraftRow()
    if (draftRow) {
      const cents = this.rowAmountCents(draftRow)
      if (draftRow.dataset.settlementType === "cash") {
        cashTenderedCents += cents
      } else {
        nonCashCents += cents
      }
    }

    let remainingDisplay = "—"
    let changeDisplay = "—"

    if (totalCents > 0) {
      const remainingAfterNonCash = Math.max(totalCents - nonCashCents, 0)
      const remainingCents = remainingAfterNonCash - Math.min(cashTenderedCents, remainingAfterNonCash)
      remainingDisplay = this.formatMoney(Math.max(remainingCents, 0))

      const changeCents = cashTenderedCents - remainingAfterNonCash
      if (cashTenderedCents > 0 && changeCents > 0) {
        changeDisplay = this.formatMoney(changeCents)
      } else if (cashTenderedCents > 0 && cashTenderedCents < remainingAfterNonCash) {
        changeDisplay = this.formatMoney(0)
      } else {
        changeDisplay = this.formatMoney(0)
      }
    } else if (totalCents < 0) {
      const tenderTotal = nonCashCents + cashTenderedCents
      const remainingCents = Math.abs(totalCents) - tenderTotal
      remainingDisplay = this.formatMoney(Math.max(remainingCents, 0))
      changeDisplay = this.formatMoney(0)
    } else {
      remainingDisplay = this.formatMoney(0)
      changeDisplay = this.formatMoney(0)
    }

    if (this.hasRemainingBalanceTarget) {
      this.remainingBalanceTarget.textContent = remainingDisplay
    }

    if (this.hasChangeDueTarget) {
      this.changeDueTarget.textContent = changeDisplay
    }

    if (this.hasTenderedTotalTarget) {
      this.tenderedTotalTarget.textContent = this.formatMoney(nonCashCents + cashTenderedCents)
    }

    if (this.hasReadyCompleteTarget) {
      const ready = this.readyToCompleteFromTotals(nonCashCents, cashTenderedCents, totalCents)
      this.readyCompleteTarget.hidden = !ready
    }

    this.updateCompleteButton(nonCashCents, cashTenderedCents, totalCents)
  }

  readyToCompleteFromTotals(nonCashCents, cashTenderedCents, totalCents) {
    if (totalCents > 0) {
      const remainingAfterNonCash = Math.max(totalCents - nonCashCents, 0)
      return nonCashCents <= totalCents && cashTenderedCents >= remainingAfterNonCash
    }

    if (totalCents < 0) {
      return Math.abs(totalCents) <= nonCashCents + cashTenderedCents
    }

    return true
  }

  updateCompleteButton(nonCashCents, cashTenderedCents, totalCents) {
    const button = this.element.querySelector("[data-pos-transaction-edit-target='completeButton']")
    if (!button) return

    if (totalCents > 0) {
      const remainingAfterNonCash = Math.max(totalCents - nonCashCents, 0)
      const ready = nonCashCents <= totalCents && cashTenderedCents >= remainingAfterNonCash
      button.disabled = !ready
    } else if (totalCents < 0) {
      const tenderTotal = nonCashCents + cashTenderedCents
      button.disabled = Math.abs(totalCents) > tenderTotal
    } else {
      button.disabled = false
    }
  }

  hideEmptyRow() {
    if (this.hasEmptyRowTarget) {
      this.emptyRowTarget.remove()
    }
  }

  showEmptyRow() {
    if (!this.hasEmptyRowTarget && this.rowsTarget.querySelector(".ss-pos-settlement-empty") == null) {
      const row = document.createElement("tr")
      row.className = "ss-pos-settlement-empty"
      row.dataset.posSettlementPanelTarget = "emptyRow"
      row.innerHTML = '<td colspan="3">No tenders yet. Add cash, card, or check.</td>'
      this.rowsTarget.appendChild(row)
    }
  }

  formatMoney(cents) {
    return `$${(cents / 100).toFixed(2)}`
  }

  focusRowEntry(row) {
    this.expandRowElement(row)

    const tenderType = row.dataset.settlementType
    if (tenderType === "store_credit" || tenderType === "gift_card" || tenderType === "stored_value") {
      if (this.focusField(row.querySelector("[data-pos-settlement-panel-target='lookupCodeField']"))) return
    }

    if (tenderType === "card") {
      if (this.focusField(row.querySelector("[data-pos-settlement-panel-target='cardBrandField']"))) return
    }

    if (this.focusField(row.querySelector("[data-settlement-amount]"))) return

    this.focusField(row.querySelector("input:not([type='hidden']), select"))
  }

  focusStoredValueAmount(row) {
    this.expandRowElement(row)
    this.focusField(row.querySelector("[data-settlement-amount]"))
  }

  shouldPrefillRemainingForRow(tenderType, row, prefillRemaining) {
    if (this.isStoredValueTenderType(tenderType)) {
      return prefillRemaining && this.storedValueBalanceCents(row) != null
    }

    return prefillRemaining
  }

  isStoredValueTenderType(tenderType) {
    return tenderType === "stored_value" || tenderType === "store_credit" || tenderType === "gift_card"
  }

  applyResolvedStoredValueType(row, payload) {
    const resolvedType = payload.resolved_tender_type
    if (!resolvedType) return

    row.dataset.settlementType = resolvedType
    const tenderTypeField = row.querySelector("[name*='[tender_type]']")
    if (tenderTypeField) tenderTypeField.value = resolvedType
  }

  normalizeDraftRowTenderType(row) {
    if (!this.refundValue) return row.dataset.settlementType
    if (row.dataset.settlementType !== "stored_value") return row.dataset.settlementType

    this.applyResolvedStoredValueType(row, { resolved_tender_type: "store_credit" })
    return "store_credit"
  }

  storedValueTypeLabel(tenderType) {
    if (tenderType === "gift_card") return "Gift card"
    if (tenderType === "store_credit") return "Store credit"
    return "Stored value"
  }

  focusField(field) {
    if (!field) return false

    field.focus()
    if (field.tagName !== "SELECT" && typeof field.select === "function") {
      field.select()
    }
    return true
  }

  nextSettlementIndex() {
    const selectors = [this.rowsTarget]
    if (this.hasDraftRowsTarget) selectors.push(this.draftRowsTarget)

    let max = -1
    selectors.forEach((container) => {
      container.querySelectorAll("[data-settlement-row]").forEach((row) => {
        const index = parseInt(row.dataset.settlementIndex, 10)
        if (!Number.isNaN(index)) max = Math.max(max, index)
      })
    })
    return max + 1
  }

  storedValueBalanceCents(row) {
    const balance = parseInt(row.dataset.storedValueBalanceCents, 10)
    return Number.isNaN(balance) ? null : balance
  }

  cappedStoredValueAmountCents(row, amountCents) {
    const balanceCents = this.storedValueBalanceCents(row)
    if (balanceCents == null) return amountCents

    return Math.min(amountCents, balanceCents)
  }

  clampStoredValueAmount(row) {
    if (this.refundValue) return
    if (!this.isStoredValueTenderType(row.dataset.settlementType) || row.dataset.settlementType === "stored_value") return

    const balanceCents = this.storedValueBalanceCents(row)
    if (balanceCents == null) return

    const amountCents = this.rowAmountCents(row)
    if (amountCents <= balanceCents) return

    this.setRowAmountCents(row, balanceCents)
    this.updateRowSummary(row)
  }
}
