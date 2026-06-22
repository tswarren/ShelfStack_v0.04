import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "rows",
    "emptyRow",
    "cardTemplate",
    "checkTemplate",
    "cashTemplate",
    "destroyField",
    "amountField",
    "remainingHint",
    "changeHint"
  ]

  static values = {
    totalCents: Number,
    refund: Boolean
  }

  connect() {
    this.visibleRows().forEach((row) => this.updateRowSummary(row))
    this.update()
  }

  update() {
    this.visibleRows().forEach((row) => this.updateRowSummary(row))
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
    if (existing) {
      this.expandRowElement(existing)
      this.focusRowEntry(existing)
      return
    }

    this.appendRow(this.cashTemplateTarget)
  }

  appendRow(template) {
    this.hideEmptyRow()
    const fragment = template.content.cloneNode(true)
    const row = fragment.querySelector("[data-settlement-row]")
    if (!row) return

    row.dataset.rowId = ""
    row.removeAttribute("data-destroyed")
    row.dataset.collapsed = "false"
    this.rowsTarget.appendChild(fragment)
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

    this.setRowAmountCents(row, displayCents)
    this.collapseRowIfReady(row)
    this.update()
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
  }

  collapseRowIfReady(row) {
    if (!this.rowHasAmount(row)) return

    row.dataset.collapsed = "true"
    this.updateRowSummary(row)
  }

  rowHasAmount(row) {
    return this.rowAmountCents(row) > 0
  }

  updateRowSummary(row) {
    const label = row.querySelector("[data-pos-settlement-panel-target='rowSummaryLabel']")
    if (!label) return

    label.textContent = this.rowSummaryText(row)
  }

  rowSummaryText(row) {
    const amountCents = this.rowAmountCents(row)
    const amount = this.formatMoney(amountCents)
    const tenderType = row.dataset.settlementType

    if (tenderType === "cash") {
      const prefix = this.refundValue ? "Cash refund" : "Cash tendered"
      return `${prefix} — ${amount}`
    }

    if (tenderType === "card") {
      const brandField = row.querySelector("[name*='[card_brand]']")
      const brand = brandField?.selectedOptions?.[0]?.text || "Card"
      const lastFour = row.querySelector("[name*='[card_last_four]']")?.value
      const detail = lastFour ? `${brand} ending ${lastFour}` : brand
      return `${detail} — ${amount}`
    }

    if (tenderType === "check") {
      const checkNumber = row.querySelector("[name*='[check_number]']")?.value
      const label = checkNumber ? `Check #${checkNumber}` : "Check"
      return `${label} — ${amount}`
    }

    return amount
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

    if (this.hasRemainingHintTarget) {
      if (totalCents > 0) {
        const remainingCents = totalCents - nonCashCents - Math.min(cashTenderedCents, Math.max(totalCents - nonCashCents, 0))
        if (remainingCents > 0) {
          this.remainingHintTarget.textContent = `Remaining due: ${this.formatMoney(remainingCents)}`
          this.remainingHintTarget.hidden = false
        } else {
          this.remainingHintTarget.hidden = true
        }
      } else if (totalCents < 0) {
        const tenderTotal = nonCashCents + cashTenderedCents
        const remainingCents = Math.abs(totalCents) - tenderTotal
        if (remainingCents > 0) {
          this.remainingHintTarget.textContent = `Refund still due: ${this.formatMoney(remainingCents)}`
          this.remainingHintTarget.hidden = false
        } else if (remainingCents < 0) {
          this.remainingHintTarget.textContent = `Refund exceeds due by ${this.formatMoney(Math.abs(remainingCents))}`
          this.remainingHintTarget.hidden = false
        } else {
          this.remainingHintTarget.hidden = true
        }
      } else {
        this.remainingHintTarget.hidden = true
      }
    }

    if (!this.hasChangeHintTarget || totalCents <= 0) {
      if (this.hasChangeHintTarget) {
        this.changeHintTarget.hidden = true
      }
      return
    }

    const remainingCents = totalCents - nonCashCents
    const changeCents = cashTenderedCents - remainingCents

    if (cashTenderedCents > 0 && changeCents > 0) {
      this.changeHintTarget.textContent = `Change due: ${this.formatMoney(changeCents)}`
      this.changeHintTarget.hidden = false
    } else if (cashTenderedCents > 0 && cashTenderedCents < remainingCents) {
      this.changeHintTarget.textContent = `Cash still due: ${this.formatMoney(remainingCents - cashTenderedCents)}`
      this.changeHintTarget.hidden = false
    } else {
      this.changeHintTarget.hidden = true
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
      row.innerHTML = '<td colspan="4">No settlement rows yet. Add cash, card, or check.</td>'
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
}
