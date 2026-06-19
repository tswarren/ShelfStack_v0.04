import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "total",
    "tenderRow",
    "amountField",
    "authorizationId",
    "changeHint"
  ]

  connect() {
    this.updateChange()
  }

  requestAuth(event) {
    event.preventDefault()
    const button = event.currentTarget
    document.dispatchEvent(new CustomEvent("pos:authorization-request", {
      detail: {
        authorizationType: button.dataset.authorizationType,
        message: button.dataset.authorizationMessage,
        transactionId: button.dataset.transactionId,
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

    const remaining = (totalCents - otherTotal) / 100
    this.amountFieldTargets.forEach((field) => {
      const row = field.closest("[data-tender-type]")
      if (row?.dataset.tenderType === "cash") {
        field.value = remaining.toFixed(2)
      }
    })

    this.updateChange()
  }

  updateChange() {
    if (!this.hasChangeHintTarget) return

    const totalCents = parseInt(this.totalTarget.dataset.totalCents, 10)
    if (Number.isNaN(totalCents) || totalCents <= 0) {
      this.changeHintTarget.hidden = true
      this.changeHintTarget.textContent = ""
      return
    }

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
      this.changeHintTarget.textContent = ""
    }
  }

  setAuthorizationId(event) {
    const { authorizationId } = event.detail
    if (this.hasAuthorizationIdTarget) {
      this.authorizationIdTarget.value = authorizationId
    }
  }

  formatMoney(cents) {
    return `$${(cents / 100).toFixed(2)}`
  }
}
