import { Controller } from "@hotwired/stimulus"

const FIELD_ORDER = [
  "tax_exception_reason_id",
  "certificate_number",
  "tax_exemption_note"
]

export default class extends Controller {
  static targets = [
    "reason",
    "reasonFieldWrap",
    "certificate",
    "certificateFieldWrap",
    "certificateRequiredMarker",
    "note",
    "noteFieldWrap",
    "noteRequiredMarker"
  ]

  static values = {
    invalidFields: { type: Array, default: [] }
  }

  connect() {
    this.syncRequiredMarkers()

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
    const wrap = event.target.closest("[data-pos-tax-exemption-input-target$='FieldWrap']")
    if (!wrap) return

    this.clearInvalidWrap(wrap, event.target)
  }

  reasonChanged() {
    this.clearInvalid("tax_exception_reason_id")
    this.clearInvalid("tax_exemption_note")
    this.clearInvalid("certificate_number")
    this.syncRequiredMarkers()
  }

  syncRequiredMarkers() {
    const noteRequired = this.selectedReasonRequiresNote()
    const certificateRequired = this.selectedReasonRequiresCertificate()

    if (this.hasNoteRequiredMarkerTarget) {
      this.noteRequiredMarkerTarget.hidden = !noteRequired
      this.noteRequiredMarkerTarget.setAttribute("aria-hidden", noteRequired ? "false" : "true")
    }

    if (this.hasNoteTarget) {
      this.noteTarget.setAttribute("aria-required", noteRequired ? "true" : "false")
    }

    if (this.hasCertificateRequiredMarkerTarget) {
      this.certificateRequiredMarkerTarget.hidden = !certificateRequired
      this.certificateRequiredMarkerTarget.setAttribute("aria-hidden", certificateRequired ? "false" : "true")
    }

    if (this.hasCertificateTarget) {
      this.certificateTarget.setAttribute("aria-required", certificateRequired ? "true" : "false")
    }
  }

  collectValidationErrors() {
    const invalidFields = []

    if (!this.reasonTarget?.value) {
      invalidFields.push("tax_exception_reason_id")
    }

    if (this.reasonTarget?.value) {
      if (this.selectedReasonRequiresNote() && !this.noteTarget?.value?.trim()) {
        invalidFields.push("tax_exemption_note")
      }
      if (this.selectedReasonRequiresCertificate() && !this.certificateTarget?.value?.trim()) {
        invalidFields.push("certificate_number")
      }
    }

    return invalidFields
  }

  focusFirstInvalid(invalidFields) {
    const ordered = FIELD_ORDER.filter((field) => invalidFields.includes(field))
    const field = ordered[0]
    if (!field) return

    this.inputForField(field)?.focus()
  }

  markInvalid(fieldKey) {
    const wrap = this.wrapForField(fieldKey)
    if (!wrap) return

    wrap.classList.add("ss-field--invalid")
    wrap.querySelector("input, select, textarea")?.setAttribute("aria-invalid", "true")
  }

  clearInvalid(fieldKey) {
    const wrap = this.wrapForField(fieldKey)
    if (!wrap) return

    this.clearInvalidWrap(wrap, wrap.querySelector("input, select, textarea"))
  }

  clearInvalidHighlights() {
    this.element.querySelectorAll(".ss-field--invalid").forEach((element) => {
      this.clearInvalidWrap(element, element.querySelector("input, select, textarea"))
    })
  }

  clearInvalidWrap(wrap, input) {
    wrap.classList.remove("ss-field--invalid")
    input?.setAttribute("aria-invalid", "false")
  }

  wrapForField(fieldKey) {
    switch (fieldKey) {
      case "tax_exception_reason_id":
        return this.hasReasonFieldWrapTarget ? this.reasonFieldWrapTarget : null
      case "certificate_number":
        return this.hasCertificateFieldWrapTarget ? this.certificateFieldWrapTarget : null
      case "tax_exemption_note":
        return this.hasNoteFieldWrapTarget ? this.noteFieldWrapTarget : null
      default:
        return null
    }
  }

  inputForField(fieldKey) {
    switch (fieldKey) {
      case "tax_exception_reason_id":
        return this.hasReasonTarget ? this.reasonTarget : null
      case "certificate_number":
        return this.hasCertificateTarget ? this.certificateTarget : null
      case "tax_exemption_note":
        return this.hasNoteTarget ? this.noteTarget : null
      default:
        return null
    }
  }

  selectedReasonRequiresNote() {
    if (!this.hasReasonTarget) return false

    const selected = this.reasonTarget.selectedOptions[0]
    return selected?.dataset?.requiresNote === "true"
  }

  selectedReasonRequiresCertificate() {
    if (!this.hasReasonTarget) return false

    const selected = this.reasonTarget.selectedOptions[0]
    return selected?.dataset?.requiresCertificate === "true"
  }
}
