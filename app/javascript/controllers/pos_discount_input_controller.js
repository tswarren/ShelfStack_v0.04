import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "type",
    "value",
    "reason",
    "authorizePanel",
    "authorizedStatus",
    "authorizationId"
  ]

  static values = {
    amountLabel: String,
    percentLabel: String,
    transactionId: String,
    authorizationType: { type: String, default: "discount_reason_approval" }
  }

  connect() {
    this.updateMode()
    this.syncAuthorizationUi()
  }

  updateMode() {
    if (!this.hasTypeTarget || !this.hasValueTarget) return

    const isPercent = this.typeTarget.value === "percent"
    this.valueTarget.step = "0.01"
    this.valueTarget.max = isPercent ? "100" : ""
    this.valueTarget.placeholder = "0.00"
    this.valueTarget.setAttribute("aria-label", isPercent ? this.percentLabelValue : this.amountLabelValue)
  }

  reasonChanged() {
    this.syncAuthorizationUi()
  }

  authorizationGranted(event) {
    const { authorizationId, authorizationType } = event.detail
    if (!authorizationId) return
    if (authorizationType && authorizationType !== this.authorizationTypeValue) return

    if (this.hasAuthorizationIdTarget) {
      this.authorizationIdTarget.value = authorizationId
    }

    this.syncAuthorizationUi()
  }

  requestAuthorization(event) {
    event.preventDefault()

    document.dispatchEvent(new CustomEvent("pos:authorization-request", {
      detail: {
        authorizationType: this.authorizationTypeValue,
        message: "This discount reason requires manager approval before it can be applied.",
        transactionId: this.transactionIdValue
      }
    }))
  }

  syncAuthorizationUi() {
    const requiresAuthorization = this.selectedReasonRequiresAuthorization()
    const authorized = this.authorizationPresent()

    if (this.hasAuthorizePanelTarget) {
      this.authorizePanelTarget.hidden = !requiresAuthorization || authorized
    }

    if (this.hasAuthorizedStatusTarget) {
      this.authorizedStatusTarget.hidden = !authorized
    }
  }

  selectedReasonRequiresAuthorization() {
    if (!this.hasReasonTarget) return false

    const selected = this.reasonTarget.selectedOptions[0]
    return selected?.dataset?.requiresAuthorization === "true"
  }

  authorizationPresent() {
    if (!this.hasAuthorizationIdTarget) return false

    return this.authorizationIdTarget.value.trim().length > 0
  }
}
