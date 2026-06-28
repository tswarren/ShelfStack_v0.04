import { Controller } from "@hotwired/stimulus"

const FIELD_ORDER = [
  "override_tax_category_id",
  "tax_exception_reason_id",
  "tax_override_note"
]

export default class extends Controller {
  static targets = [
    "category",
    "categoryFieldWrap",
    "reason",
    "reasonFieldWrap",
    "note",
    "noteFieldWrap",
    "noteRequiredMarker"
  ]

  connect() {
    this.syncNoteRequired()
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
    const wrap = event.target.closest("[data-pos-tax-override-input-target$='FieldWrap']")
    if (!wrap) return

    this.clearInvalidWrap(wrap, event.target)
  }

  reasonChanged() {
    this.clearInvalid("tax_exception_reason_id")
    this.clearInvalid("tax_override_note")
    this.syncNoteRequired()
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

    if (!this.categoryTarget?.value) {
      invalidFields.push("override_tax_category_id")
    }

    if (!this.reasonTarget?.value) {
      invalidFields.push("tax_exception_reason_id")
    }

    if (this.reasonTarget?.value && this.selectedReasonRequiresNote() && !this.noteTarget?.value?.trim()) {
      invalidFields.push("tax_override_note")
    }

    return invalidFields
  }

  focusFirstInvalid(invalidFields) {
    const ordered = FIELD_ORDER.filter((field) => invalidFields.includes(field))
    const field = ordered[0]
    if (!field) return

    const input = this.inputForField(field)
    input?.focus()
  }

  markInvalid(fieldKey) {
    const wrap = this.wrapForField(fieldKey)
    if (!wrap) return

    wrap.classList.add("ss-field--invalid")
    wrap.querySelector("input, select")?.setAttribute("aria-invalid", "true")
  }

  clearInvalid(fieldKey) {
    const wrap = this.wrapForField(fieldKey)
    if (!wrap) return

    this.clearInvalidWrap(wrap, wrap.querySelector("input, select"))
  }

  clearInvalidHighlights() {
    this.element.querySelectorAll(".ss-field--invalid").forEach((element) => {
      this.clearInvalidWrap(element, element.querySelector("input, select"))
    })
  }

  clearInvalidWrap(wrap, input) {
    wrap.classList.remove("ss-field--invalid")
    input?.setAttribute("aria-invalid", "false")
  }

  wrapForField(fieldKey) {
    switch (fieldKey) {
      case "override_tax_category_id":
        return this.hasCategoryFieldWrapTarget ? this.categoryFieldWrapTarget : null
      case "tax_exception_reason_id":
        return this.hasReasonFieldWrapTarget ? this.reasonFieldWrapTarget : null
      case "tax_override_note":
        return this.hasNoteFieldWrapTarget ? this.noteFieldWrapTarget : null
      default:
        return null
    }
  }

  inputForField(fieldKey) {
    switch (fieldKey) {
      case "override_tax_category_id":
        return this.hasCategoryTarget ? this.categoryTarget : null
      case "tax_exception_reason_id":
        return this.hasReasonTarget ? this.reasonTarget : null
      case "tax_override_note":
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
}
