import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "body",
    "template",
    "line",
    "footer",
    "totalUnits",
    "totalCost",
    "totalExpected",
    "totalReceived",
    "totalAccepted",
    "totalCredit"
  ]

  static values = {
    quantityField: String,
    mergeDuplicates: { type: Boolean, default: true },
    costMode: { type: String, default: "unit" }
  }

  connect() {
    this.ensureBlankRow()
    this.updateTotals()
  }

  addLine(event) {
    if (event) event.preventDefault()
    this.insertRowFromTemplate()
    this.ensureBlankRow()
    this.updateTotals()
  }

  removeLine(event) {
    event.preventDefault()
    const row = event.target.closest("[data-purchasing-line-table-target='line']")
    if (!row) return

    const destroyField = row.querySelector("[data-purchasing-line-table-target='destroy']")
    if (destroyField) {
      destroyField.value = "1"
      row.style.display = "none"
    } else {
      row.remove()
    }

    this.ensureBlankRow()
    this.updateTotals()
  }

  rowCommitted(event) {
    const row = event.target.closest("[data-purchasing-line-table-target='line']")
    if (!row || !event.detail?.variantId) return

    if (this.mergeDuplicatesValue && event.detail.mergeAllowed !== false) {
      const merged = this.mergeDuplicateRow(row, event.detail.variantId, event.detail.quantity)
      if (merged) {
        this.ensureBlankRow()
        this.updateTotals()
        this.focusBlankScan()
        return
      }
    }

    this.ensureBlankRow()
    this.updateTotals()
    this.focusBlankScan()
  }

  mergeDuplicateRow(currentRow, variantId, quantity) {
    const existing = this.lineTargets.find((row) => {
      if (row === currentRow || row.style.display === "none") return false
      if (row.dataset.mergeAllowed === "false") return false
      const field = row.querySelector("[data-purchasing-line-row-target='variantId']")
      return field && field.value === String(variantId)
    })

    if (!existing) return false

    const qtyFieldName = this.quantityFieldValue
    const existingQty = existing.querySelector(`[name*='[${qtyFieldName}]']`)
    const currentQty = currentRow.querySelector(`[name*='[${qtyFieldName}]']`)
    if (!existingQty || !currentQty) return false

    const addQty = parseInt(currentQty.value, 10) || parseInt(quantity, 10) || 1
    const priorQty = parseInt(existingQty.value, 10) || 0
    existingQty.value = priorQty + addQty

    const destroyField = currentRow.querySelector("[data-purchasing-line-table-target='destroy']")
    if (destroyField) {
      destroyField.value = "1"
      currentRow.style.display = "none"
    } else {
      currentRow.remove()
    }

    return true
  }

  insertRowFromTemplate() {
    const content = this.templateTarget.content.cloneNode(true)
    const index = Date.now().toString()
    content.querySelectorAll("[name]").forEach((element) => {
      element.name = element.name.replace(/NEW_RECORD/g, index)
      if (element.id) element.id = element.id.replace(/NEW_RECORD/g, index)
    })
    this.bodyTarget.appendChild(content)
  }

  ensureBlankRow() {
    const visibleRows = this.lineTargets.filter((row) => row.style.display !== "none")
    const blankRows = visibleRows.filter((row) => row.dataset.blankRow === "true")
    if (blankRows.length === 0) {
      this.insertRowFromTemplate()
    } else if (blankRows.length > 1) {
      blankRows.slice(1).forEach((row) => row.remove())
    }
  }

  focusBlankScan() {
    const blank = this.lineTargets.find((row) => row.style.display !== "none" && row.dataset.blankRow === "true")
    const input = blank?.querySelector("[data-purchasing-line-row-target='lookupInput']")
    input?.focus()
  }

  receiveAllAsExpected(event) {
    event.preventDefault()
    this.lineTargets.forEach((row) => {
      if (row.style.display === "none" || row.dataset.blankRow === "true") return
      const expected = row.querySelector("[data-purchasing-line-row-target='quantityExpected']")
      const received = row.querySelector("[data-purchasing-line-row-target='quantityReceived']")
      const accepted = row.querySelector("[data-purchasing-line-row-target='quantityAccepted']")
      if (!expected || !received || !accepted) return
      received.value = expected.value
      accepted.value = expected.value
    })
    this.updateTotals()
  }

  updateTotals() {
    let units = 0
    let costCents = 0
    let expected = 0
    let received = 0
    let accepted = 0
    let credit = 0

    this.lineTargets.forEach((row) => {
      if (row.style.display === "none" || row.dataset.blankRow === "true") return

      const qty = parseInt(row.querySelector(`[name*='[${this.quantityFieldValue}]']`)?.value, 10) || 0
      units += qty

      const unitCost = parseInt(row.querySelector("[name*='[unit_cost_cents]']")?.value, 10) || 0
      if (this.costModeValue === "credit") {
        const creditAmount = parseInt(row.querySelector("[name*='[credit_amount_cents]']")?.value, 10) || 0
        credit += creditAmount
      } else {
        costCents += unitCost * qty
      }

      expected += parseInt(row.querySelector("[name*='[quantity_expected]']")?.value, 10) || 0
      received += parseInt(row.querySelector("[name*='[quantity_received]']")?.value, 10) || 0
      accepted += parseInt(row.querySelector("[name*='[quantity_accepted]']")?.value, 10) || 0
    })

    if (this.hasTotalUnitsTarget) this.totalUnitsTarget.textContent = units
    if (this.hasTotalCostTarget) this.totalCostTarget.textContent = this.formatCents(costCents)
    if (this.hasTotalExpectedTarget) this.totalExpectedTarget.textContent = expected
    if (this.hasTotalReceivedTarget) this.totalReceivedTarget.textContent = received
    if (this.hasTotalAcceptedTarget) this.totalAcceptedTarget.textContent = accepted
    if (this.hasTotalCreditTarget) this.totalCreditTarget.textContent = this.formatCents(credit)
  }

  formatCents(cents) {
    return `$${(cents / 100).toFixed(2)}`
  }
}
