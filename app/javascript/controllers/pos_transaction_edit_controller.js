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
    this.refreshReadiness()
  }

  updateChange() {
    this.updateHints()
    this.scheduleReadinessPreview()
  }

  scheduleReadinessPreview() {
    clearTimeout(this.previewTimer)
    this.previewTimer = setTimeout(() => this.refreshReadiness(), 150)
  }

  refreshReadiness() {
    if (!this.hasReadinessUrlValue) return

    const body = new FormData()
    this.amountFieldTargets.forEach((field) => {
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
      body
    })
      .then((response) => response.json())
      .then((data) => this.applyPreview(data))
      .catch(() => {})
  }

  applyPreview(data) {
    if (!this.hasCompleteButtonTarget) return

    this.completeButtonTarget.disabled = !data.complete_ready
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

  fillCash(event) {
    event.preventDefault()
    const totalCents = parseInt(this.totalTarget.dataset.totalCents, 10)
    let otherTotal = 0

    this.amountFieldTargets.forEach((field) => {
      const row = field.closest("[data-tender-type]")
      if (row?.dataset.tenderType !== "cash") {
        otherTotal += Math.round(parseFloat(field.value || "0") * 100)
      }
    })

    const remainingCents = totalCents - otherTotal
    const displayCents = totalCents < 0 ? Math.abs(remainingCents) : remainingCents

    this.amountFieldTargets.forEach((field) => {
      const row = field.closest("[data-tender-type]")
      if (row?.dataset.tenderType === "cash") {
        field.value = (displayCents / 100).toFixed(2)
      }
    })

    this.updateChange()
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

    this.amountFieldTargets.forEach((field) => {
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
