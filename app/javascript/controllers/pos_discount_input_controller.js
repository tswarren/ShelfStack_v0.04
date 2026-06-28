import { Controller } from "@hotwired/stimulus"

const FIELD_ORDER = [
  "discount_reason_id",
  "discount_value",
  "discount_note",
  "discount_authorization"
]

export default class extends Controller {
  static targets = [
    "type",
    "value",
    "valueWrap",
    "valueFieldWrap",
    "reason",
    "reasonFieldWrap",
    "note",
    "noteFieldWrap",
    "noteRequiredMarker",
    "modeButton",
    "modeGroup",
    "amountAdornment",
    "percentAdornment",
    "authorizePanel",
    "authorizedStatus",
    "authorizationId",
    "previewTotal"
  ]

  static values = {
    amountLabel: String,
    percentLabel: String,
    transactionId: String,
    authorizationType: { type: String, default: "discount_reason_approval" },
    invalidFields: { type: Array, default: [] },
    showPreview: { type: Boolean, default: false },
    eligibleBaseCents: { type: Number, default: 0 },
    currentTotalCents: { type: Number, default: 0 }
  }

  connect() {
    this.pendingAuthorizationSubmit = false
    this.syncModeButtons()
    this.updateMode()
    this.syncAuthorizationUi()
    this.syncNoteRequired()
    this.updatePreview()

    if (this.invalidFieldsValue.length > 0) {
      this.invalidFieldsValue.forEach((field) => this.markInvalid(field))
      requestAnimationFrame(() => this.focusFirstInvalid(this.invalidFieldsValue))
    }
  }

  validateSubmit(event) {
    this.clearInvalidHighlights()
    const invalidFields = this.collectValidationErrors()
    if (invalidFields.length === 0) return

    event.preventDefault()
    event.stopPropagation()

    invalidFields.forEach((field) => this.markInvalid(field))
    this.focusFirstInvalid(invalidFields)
  }

  clearFieldInvalid(event) {
    const wrap = event.target.closest("[data-pos-discount-input-target$='FieldWrap'], [data-pos-discount-input-target='authorizePanel']")
    if (!wrap) return

    this.clearInvalidWrap(wrap, event.target)

    if (event.target === this.valueTarget) {
      this.valueWrapTarget?.classList.remove("ss-pos-discount-value--invalid")
    }
  }

  selectMode(event) {
    event.preventDefault()
    if (!this.hasTypeTarget) return

    const mode = event.currentTarget.dataset.mode
    if (!mode || this.typeTarget.value === mode) return

    this.typeTarget.value = mode
    this.syncModeButtons()
    this.updateMode()
    this.clearInvalid("discount_value")
    this.updatePreview()

    if (this.hasValueTarget) {
      this.valueTarget.focus()
      this.valueTarget.select()
    }
  }

  updateMode() {
    if (!this.hasTypeTarget || !this.hasValueTarget) return

    const isPercent = this.typeTarget.value === "percent"
    this.valueTarget.step = "0.01"
    this.valueTarget.max = isPercent ? "100" : ""
    this.valueTarget.placeholder = "0.00"
    this.valueTarget.setAttribute("aria-label", isPercent ? this.percentLabelValue : this.amountLabelValue)

    if (this.hasValueWrapTarget) {
      this.valueWrapTarget.dataset.discountMode = isPercent ? "percent" : "amount"
    }

    if (this.hasAmountAdornmentTarget) {
      this.amountAdornmentTarget.hidden = isPercent
    }

    if (this.hasPercentAdornmentTarget) {
      this.percentAdornmentTarget.hidden = !isPercent
    }
  }

  syncModeButtons() {
    if (!this.hasTypeTarget || !this.hasModeButtonTarget) return

    const mode = this.typeTarget.value
    this.modeButtonTargets.forEach((button) => {
      const active = button.dataset.mode === mode
      button.classList.toggle("ss-pos-discount-mode__btn--active", active)
      button.setAttribute("aria-pressed", active ? "true" : "false")
    })
  }

  reasonChanged() {
    this.clearInvalid("discount_reason_id")
    this.clearInvalid("discount_note")
    this.syncAuthorizationUi()
    this.syncNoteRequired()
    this.updatePreview()
  }

  updatePreview() {
    if (!this.showPreviewValue || !this.hasPreviewTotalTarget) return

    const discountCents = this.estimatedDiscountCents()
    const previewCents = Math.max(0, this.currentTotalCentsValue - discountCents)
    this.previewTotalTarget.textContent = this.formatMoney(previewCents)
  }

  estimatedDiscountCents() {
    const raw = this.valueTarget?.value?.trim()
    if (!raw) return 0

    const base = this.eligibleBaseCentsValue
    if (this.typeTarget?.value === "percent") {
      const percent = Number.parseFloat(raw)
      if (Number.isNaN(percent) || percent <= 0) return 0

      return Math.round((base * percent) / 100)
    }

    const amount = Number.parseFloat(raw)
    if (Number.isNaN(amount) || amount <= 0) return 0

    return Math.min(Math.round(amount * 100), base)
  }

  formatMoney(cents) {
    return new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" }).format(cents / 100)
  }

  authorizationGranted(event) {
    const { authorizationId, authorizationType } = event.detail
    if (!authorizationId) return
    if (authorizationType && authorizationType !== this.authorizationTypeValue) return

    if (this.hasAuthorizationIdTarget) {
      this.authorizationIdTarget.value = authorizationId
    }

    this.clearInvalid("discount_authorization")
    this.syncAuthorizationUi()

    if (!this.pendingAuthorizationSubmit) return

    this.pendingAuthorizationSubmit = false
    this.submitIfReady()
  }

  submitIfReady() {
    if (this.collectValidationErrors().length > 0) return

    this.element.closest("form")?.requestSubmit()
  }

  requestAuthorization(event) {
    event.preventDefault()
    this.pendingAuthorizationSubmit = true

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
      const forceVisible = this.hasInvalidWrap(this.authorizePanelTarget)
      this.authorizePanelTarget.hidden = !forceVisible && (!requiresAuthorization || authorized)
    }

    if (this.hasAuthorizedStatusTarget) {
      this.authorizedStatusTarget.hidden = !authorized
    }
  }

  syncNoteRequired() {
    const required = this.selectedReasonRequiresNote()

    if (this.hasNoteRequiredMarkerTarget) {
      this.noteRequiredMarkerTarget.hidden = !required
      this.noteRequiredMarkerTarget.setAttribute("aria-hidden", required ? "false" : "true")
    }

    if (this.hasNoteTarget) {
      this.noteTarget.setAttribute("aria-required", required ? "true" : "false")
    }
  }

  collectValidationErrors() {
    const invalidFields = []

    if (!this.reasonTarget?.value) {
      invalidFields.push("discount_reason_id")
    }

    if (!this.valueTarget?.value?.trim()) {
      invalidFields.push("discount_value")
    }

    if (this.reasonTarget?.value) {
      if (this.selectedReasonRequiresNote() && !this.noteTarget?.value?.trim()) {
        invalidFields.push("discount_note")
      }
      if (this.selectedReasonRequiresAuthorization() && !this.authorizationPresent()) {
        invalidFields.push("discount_authorization")
      }
    }

    return invalidFields
  }

  focusFirstInvalid(invalidFields) {
    const ordered = FIELD_ORDER.filter((field) => invalidFields.includes(field))
    const field = ordered[0]
    if (!field) return

    if (field === "discount_value" && this.hasValueTarget) {
      this.valueTarget.focus()
      this.valueTarget.select()
      return
    }

    if (field === "discount_reason_id" && this.hasReasonTarget) {
      this.reasonTarget.focus()
      return
    }

    if (field === "discount_note" && this.hasNoteTarget) {
      this.noteTarget.focus()
      return
    }

    if (field === "discount_authorization") {
      this.authorizePanelTarget?.querySelector("button")?.focus()
    }
  }

  markInvalid(fieldKey) {
    const wrap = this.wrapForField(fieldKey)
    if (!wrap) return

    if (fieldKey === "discount_value") {
      wrap.classList.add("ss-field--invalid")
      this.valueWrapTarget?.classList.add("ss-pos-discount-value--invalid")
      this.valueTarget?.setAttribute("aria-invalid", "true")
    } else if (fieldKey === "discount_authorization") {
      wrap.classList.add("ss-pos-discount-auth--invalid")
      wrap.hidden = false
    } else {
      wrap.classList.add("ss-field--invalid")
      wrap.querySelector("input, select, textarea")?.setAttribute("aria-invalid", "true")
    }
  }

  clearInvalid(fieldKey) {
    const wrap = this.wrapForField(fieldKey)
    if (!wrap) return

    this.clearInvalidWrap(wrap, wrap.querySelector("input, select, textarea"))

    if (fieldKey === "discount_value") {
      this.valueWrapTarget?.classList.remove("ss-pos-discount-value--invalid")
      this.valueTarget?.setAttribute("aria-invalid", "false")
    }

    this.syncAuthorizationUi()
  }

  clearInvalidHighlights() {
    this.element.querySelectorAll(".ss-field--invalid, .ss-pos-discount-auth--invalid, .ss-pos-discount-value--invalid").forEach((element) => {
      this.clearInvalidWrap(element, element.querySelector("input, select, textarea"))
    })
  }

  clearInvalidWrap(wrap, input) {
    wrap.classList.remove("ss-field--invalid", "ss-pos-discount-auth--invalid")
    this.valueWrapTarget?.classList.remove("ss-pos-discount-value--invalid")
    input?.setAttribute("aria-invalid", "false")
  }

  wrapForField(fieldKey) {
    switch (fieldKey) {
      case "discount_value":
        return this.hasValueFieldWrapTarget ? this.valueFieldWrapTarget : null
      case "discount_reason_id":
        return this.hasReasonFieldWrapTarget ? this.reasonFieldWrapTarget : null
      case "discount_note":
        return this.hasNoteFieldWrapTarget ? this.noteFieldWrapTarget : null
      case "discount_authorization":
        return this.hasAuthorizePanelTarget ? this.authorizePanelTarget : null
      default:
        return null
    }
  }

  hasInvalidWrap(element) {
    return element?.classList.contains("ss-field--invalid") ||
      element?.classList.contains("ss-pos-discount-auth--invalid")
  }

  selectedReasonRequiresAuthorization() {
    if (!this.hasReasonTarget) return false

    const selected = this.reasonTarget.selectedOptions[0]
    return selected?.dataset?.requiresAuthorization === "true"
  }

  selectedReasonRequiresNote() {
    if (!this.hasReasonTarget) return false

    const selected = this.reasonTarget.selectedOptions[0]
    return selected?.dataset?.requiresNote === "true"
  }

  authorizationPresent() {
    if (!this.hasAuthorizationIdTarget) return false

    return this.authorizationIdTarget.value.trim().length > 0
  }
}
