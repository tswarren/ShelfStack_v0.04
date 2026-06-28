import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "total",
    "amountField",
    "authorizationId",
    "confirmInactive",
    "confirmInactiveField",
    "changeHint",
    "remainingHint",
    "completeButton",
    "settlementButton"
  ]

  static values = {
    readinessUrl: String,
    transactionId: String
  }

  connect() {
    this.previewTimer = null
    this.updateChange()
  }

  disconnect() {
    clearTimeout(this.previewTimer)
  }

  updateChange() {
    this.updateHints()
    this.scheduleReadinessPreview()
  }

  scheduleReadinessPreview() {
    clearTimeout(this.previewTimer)
    this.previewTimer = setTimeout(() => this.refreshReadiness(), 150)
  }

  settlementAmountFields() {
    const modal = document.getElementById("pos_settlement_modal")
    if (!modal) return []

    return Array.from(modal.querySelectorAll("[data-settlement-amount]")).filter((field) => {
      const row = field.closest("[data-settlement-row]")
      if (!row) return true

      return row.dataset.destroyed !== "true" && !row.hidden
    })
  }

  tenderAmountFields() {
    const settlementFields = this.settlementAmountFields()
    if (settlementFields.length > 0) {
      return settlementFields
    }

    if (this.amountFieldTargets.length > 0) {
      return this.amountFieldTargets
    }

    return Array.from(this.element.querySelectorAll("[data-pos-transaction-edit-target='amountField']"))
  }

  refreshReadiness() {
    if (!this.hasReadinessUrlValue) return

    const body = new FormData()
    if (!this.appendSettlementInputs(body)) {
      const fields = this.tenderAmountFields()
      if (fields.length === 0) return

      fields.forEach((field) => {
        const row = field.closest("[data-tender-type]")
        body.append("tenders[][amount_dollars]", field.value || "0")
        body.append("tenders[][tender_type]", row?.dataset.tenderType || "cash")
      })
    }

    if (this.hasAuthorizationIdTarget && this.authorizationIdTarget.value) {
      body.append("pos_authorization_id", this.authorizationIdTarget.value)
    }

    if (this.hasConfirmInactiveFieldTarget && !this.confirmInactiveFieldTarget.disabled) {
      body.append("confirm_inactive", "1")
    }

    fetch(this.readinessUrlValue, {
      method: "POST",
      headers: {
        "X-CSRF-Token": this.csrfToken,
        Accept: "application/json"
      },
      credentials: "same-origin",
      body
    })
      .then((response) => {
        if (!response.ok) throw new Error(`readiness preview failed (${response.status})`)

        return response.json()
      })
      .then((data) => this.applyPreview(data))
      .catch(() => {})
  }

  applyPreview(data) {
    if (data.panel_html !== undefined) {
      document.querySelectorAll(".js-pos-readiness-host").forEach((panel) => {
        panel.innerHTML = data.panel_html
        panel.hidden = data.readiness_visible !== true
      })
    }

    if (this.hasCompleteButtonTarget) {
      this.completeButtonTarget.disabled = data.complete_ready !== true
      if (data.complete_label) {
        this.completeButtonTarget.value = data.complete_label
      }
    }

    if (this.hasSettlementButtonTarget) {
      this.settlementButtonTarget.disabled = data.structural_blocked === true
      if (data.complete_label) {
        this.settlementButtonTarget.textContent = this.settlementButtonLabel(data.complete_label)
      }
    }
  }

  settlementButtonLabel(completeLabel) {
    if (completeLabel.startsWith("Complete ")) {
      return `Settlement — ${completeLabel.slice("Complete ".length)}`
    }

    return completeLabel
  }

  requestAuth(event) {
    event.preventDefault()
    const button = event.currentTarget
    document.dispatchEvent(new CustomEvent("pos:authorization-request", {
      detail: {
        authorizationType: button.dataset.authorizationType,
        message: button.dataset.authorizationMessage,
        transactionId: button.dataset.transactionId || this.transactionIdValue,
        registerSessionId: button.dataset.registerSessionId
      }
    }))
  }

  fillTender(event) {
    event.preventDefault()
    const panel = this.application.getControllerForElementAndIdentifier(this.element, "pos-settlement-panel")
    if (!panel) return

    panel.fillCashFromReadiness()
    this.updateChange()
  }

  fillCash(event) {
    event.currentTarget.dataset.tenderType = "cash"
    this.fillTender(event)
  }

  focusScan(event) {
    event?.preventDefault()
    document.querySelector(".ss-pos-scan-input")?.focus()
  }

  confirmInactive(event) {
    if (!this.hasConfirmInactiveFieldTarget) return

    this.confirmInactiveFieldTarget.disabled = !event.target.checked
    this.refreshReadiness()
  }

  updateHints() {
    const totalCents = parseInt(this.totalTarget.dataset.totalCents, 10)
    if (Number.isNaN(totalCents)) return

    let nonCashCents = 0
    let cashTenderedCents = 0

    this.tenderAmountFields().forEach((field) => {
      const row = field.closest("[data-settlement-row]") || field.closest("[data-tender-type]")
      const tenderType = row?.dataset.settlementType || row?.dataset.tenderType
      const cents = Math.round(parseFloat(field.value || "0") * 100)
      if (tenderType === "cash") {
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
  }

  setAuthorizationId(event) {
    const { authorizationId, authorizationType } = event.detail
    if (!authorizationId) return

    this.authorizationIdTargets.forEach((field) => {
      field.value = authorizationId
    })

    if (authorizationType === "discount_reason_approval" || authorizationType === "void_transaction") {
      return
    }

    const url = new URL(window.location.href)
    url.searchParams.set("pos_authorization_id", authorizationId)
    window.Turbo.visit(url.toString())
  }

  formatMoney(cents) {
    return `$${(cents / 100).toFixed(2)}`
  }

  appendSettlementInputs(body) {
    const modal = document.getElementById("pos_settlement_modal")
    if (!modal) return false

    const rows = modal.querySelectorAll("[data-settlement-row]")
    if (rows.length === 0) return false

    rows.forEach((row) => {
      const rowIndex = row.dataset.settlementIndex
      if (!rowIndex) return

      if (row.dataset.destroyed === "true" || row.hidden) {
        body.append(`settlements[${rowIndex}][id]`, row.dataset.rowId || "")
        body.append(`settlements[${rowIndex}][_destroy]`, "1")
        body.append(`settlements[${rowIndex}][tender_type]`, row.dataset.settlementType || "")
        return
      }

      row.querySelectorAll("input, select, textarea").forEach((field) => {
        if (!field.name || field.disabled) return
        body.append(field.name, field.value || "")
      })
    })

    return true
  }

  get csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content
  }
}
