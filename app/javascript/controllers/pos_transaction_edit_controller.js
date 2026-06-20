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
    "completeButton"
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

  tenderAmountFields() {
    if (this.amountFieldTargets.length > 0) {
      return this.amountFieldTargets
    }

    return Array.from(this.element.querySelectorAll("[data-pos-transaction-edit-target='amountField']"))
  }

  refreshReadiness() {
    if (!this.hasReadinessUrlValue) return

    const fields = this.tenderAmountFields()
    if (fields.length === 0) return

    const body = new FormData()
    fields.forEach((field) => {
      const row = field.closest("[data-tender-type]")
      body.append("tenders[][amount_dollars]", field.value || "0")
      body.append("tenders[][tender_type]", row?.dataset.tenderType || "cash")
    })

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
    if (data.panel_html) {
      const panel = document.getElementById("pos_readiness")
      if (panel) panel.innerHTML = data.panel_html
    }

    if (!this.hasCompleteButtonTarget) return

    this.completeButtonTarget.disabled = data.complete_ready !== true
    if (data.complete_label) {
      this.completeButtonTarget.value = data.complete_label
    }
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
    const tenderType = event.currentTarget.dataset.tenderType
    if (!tenderType) return

    const totalCents = parseInt(this.totalTarget.dataset.totalCents, 10)
    if (Number.isNaN(totalCents)) return

    let otherTotal = 0
    this.tenderAmountFields().forEach((field) => {
      const row = field.closest("[data-tender-type]")
      if (row?.dataset.tenderType !== tenderType) {
        otherTotal += Math.round(parseFloat(field.value || "0") * 100)
      }
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

    this.tenderAmountFields().forEach((field) => {
      const row = field.closest("[data-tender-type]")
      if (row?.dataset.tenderType === tenderType) {
        field.value = (displayCents / 100).toFixed(2)
      }
    })

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
      const row = field.closest("[data-tender-type]")
      const cents = Math.round(parseFloat(field.value || "0") * 100)
      if (row?.dataset.tenderType === "cash") {
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
    const { authorizationId } = event.detail
    if (!authorizationId) return

    this.authorizationIdTargets.forEach((field) => {
      field.value = authorizationId
    })

    const url = new URL(window.location.href)
    url.searchParams.set("pos_authorization_id", authorizationId)
    window.Turbo.visit(url.toString())
  }

  formatMoney(cents) {
    return `$${(cents / 100).toFixed(2)}`
  }

  get csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content
  }
}
