import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "modal",
    "rows",
    "emptyRow",
    "cardTemplate",
    "checkTemplate",
    "cashTemplate",
    "storeCreditTemplate",
    "giftCardTemplate",
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
    lookupUrl: String
  }

  connect() {
    this.boundKeydown = this.keydown.bind(this)
    this.visibleRows().forEach((row) => {
      this.syncRowLayout(row)
      this.updateRowSummary(row)
    })
    this.update()
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundKeydown)
  }

  open(event) {
    event?.preventDefault()
    if (!this.hasModalTarget) return

    this.modalTarget.hidden = false
    document.body.classList.add("ss-pos-modal-open")
    document.addEventListener("keydown", this.boundKeydown)
    this.update()
    this.element.dispatchEvent(new CustomEvent("pos:settlement-opened", { bubbles: true }))

    const rows = this.visibleRows()
    const emptyAmountRow = rows.find((row) => !this.rowHasAmount(row))
    if (emptyAmountRow) {
      this.focusRowEntry(emptyAmountRow)
    } else if (rows.length === 0) {
      this.modalTarget.querySelector(".ss-pos-settlement-modal-footer__center .ss-btn")?.focus()
    } else {
      this.modalTarget.querySelector("[data-pos-transaction-edit-target='completeButton']")?.focus()
    }
  }

  close(event) {
    event?.preventDefault()
    if (!this.hasModalTarget) return

    this.modalTarget.hidden = true
    document.body.classList.remove("ss-pos-modal-open")
    document.removeEventListener("keydown", this.boundKeydown)
  }

  keydown(event) {
    if (event.key === "Escape") {
      this.close()
    }
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
    this.open()
    this.ensureCashAndFillRemaining()
  }

  ensureCashAndFillRemaining() {
    let row = this.rowsTarget.querySelector("[data-settlement-type='cash']:not([data-destroyed='true'])")
    if (!row || row.hidden) {
      this.appendRow(this.cashTemplateTarget)
      row = this.visibleRows().find((visibleRow) => visibleRow.dataset.settlementType === "cash")
    }

    if (row) {
      this.fillRemainingForRow(row, "cash")
    }
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

      const accountField = row.querySelector("[name*='[stored_value_account_id]']")
      const identifierField = row.querySelector("[name*='[stored_value_identifier_id]']")
      if (accountField) accountField.value = payload.account_id
      if (identifierField) identifierField.value = payload.identifier_id
      row.dataset.storedValueBalanceCents = String(payload.current_balance_cents)

      if (statusEl) {
        statusEl.textContent = `${payload.display_value_masked} · Balance ${this.formatMoney(payload.current_balance_cents)}`
      }

      this.clampStoredValueAmount(row)
      if (this.rowAmountCents(row) === 0) {
        this.fillRemainingForRow(row, tenderType)
      } else {
        this.clampStoredValueAmount(row)
      }
      this.updateRowSummary(row)
      this.updateHints()
      this.dispatchUpdate()
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
    if (row.dataset.rowId) {
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
    this.visibleRows().forEach((visibleRow) => {
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

    if (tenderType === "store_credit" || tenderType === "gift_card") {
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

    if (tenderType === "store_credit" || tenderType === "gift_card") {
      const base = tenderType === "gift_card" ? "Gift card" : "Store credit"
      const status = row.querySelector("[data-pos-settlement-panel-target='lookupStatus']")?.textContent
      const label = status ? `${base} ${status.split("·")[0].trim()}` : base
      return { label, amount }
    }

    return { label: tenderType, amount }
  }

  visibleRows() {
    return Array.from(this.rowsTarget.querySelectorAll("[data-settlement-row]"))
      .filter((row) => row.dataset.destroyed !== "true" && !row.hidden)
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

    this.updateCompleteButton(nonCashCents, cashTenderedCents, totalCents)
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

    const amountField = row.querySelector("[data-settlement-amount]")
    if (amountField) {
      amountField.focus()
      if (typeof amountField.select === "function") amountField.select()
      return
    }

    row.querySelector("input:not([type='hidden']), select")?.focus()
  }

  nextSettlementIndex() {
    const rows = this.rowsTarget.querySelectorAll("[data-settlement-row]")
    let max = -1
    rows.forEach((row) => {
      const index = parseInt(row.dataset.settlementIndex, 10)
      if (!Number.isNaN(index)) max = Math.max(max, index)
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
    if (row.dataset.settlementType !== "store_credit" && row.dataset.settlementType !== "gift_card") return

    const balanceCents = this.storedValueBalanceCents(row)
    if (balanceCents == null) return

    const amountCents = this.rowAmountCents(row)
    if (amountCents <= balanceCents) return

    this.setRowAmountCents(row, balanceCents)
    this.updateRowSummary(row)
  }
}
