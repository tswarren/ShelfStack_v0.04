import { Controller } from "@hotwired/stimulus"

// v0.04-16.1A: client show/hide/disable from EntryContext. No Turbo Frame form reload.
export default class extends Controller {
  static targets = [
    "staffItemKind",
    "digital",
    "format",
    "variationType",
    "sections",
    "genrePicker"
  ]

  static values = {
    contextUrl: String,
    context: Object
  }

  connect() {
    this.applyContext(this.hasContextValue ? this.contextValue : {})
    this.element.closest("form")?.addEventListener("submit", this.ensureVisibleFieldsEnabled)
  }

  disconnect() {
    this.element.closest("form")?.removeEventListener("submit", this.ensureVisibleFieldsEnabled)
  }

  // Disabled fields are omitted from submit. Re-enable shells marked visible so
  // preferred vendor / other selling defaults are not dropped on create/update.
  ensureVisibleFieldsEnabled = () => {
    this.element.querySelectorAll('[data-product-field-key][data-visible="true"]').forEach((shell) => {
      shell.querySelectorAll("input, select, textarea").forEach((input) => {
        if (input.dataset.productFieldKeepEnabled === "true") return
        input.disabled = false
      })
    })
  }

  onDriverChange(event) {
    event?.preventDefault?.()
    this.refreshContext()
  }

  async refreshContext({ fromFormatClear = false } = {}) {
    if (!this.hasContextUrlValue || !this.contextUrlValue) return

    const params = new URLSearchParams()
    const staffItemKind = this.staffItemKindValue()
    const digital = this.digitalValue()
    const formatId = this.formatValue()
    const variationType = this.variationTypeValue()

    if (staffItemKind) params.set("staff_item_kind", staffItemKind)
    if (digital !== null) params.set("digital", digital ? "1" : "0")
    if (formatId) params.set("format_id", formatId)
    if (variationType) params.set("variation_type", variationType)

    try {
      const response = await fetch(`${this.contextUrlValue}?${params.toString()}`, {
        headers: {
          Accept: "application/json",
          "X-Requested-With": "XMLHttpRequest"
        },
        credentials: "same-origin"
      })
      if (!response.ok) return
      const payload = await response.json()
      this.contextValue = payload
      const clearedFormat = this.applyContext(payload)
      if (clearedFormat && !fromFormatClear) {
        await this.refreshContext({ fromFormatClear: true })
      }
    } catch (_error) {
      // Keep current visibility if context fetch fails.
    }
  }

  applyContext(context) {
    if (!context || typeof context !== "object") return false

    const fieldVisibility = context.field_visibility || {}
    Object.entries(fieldVisibility).forEach(([key, state]) => {
      const visible = Boolean(state?.visible)
      const required = Boolean(state?.required)
      this.applyFieldVisibility(key, visible, required)
    })

    this.applyFieldLabels(context.field_labels || {})
    this.applySectionVisibility(fieldVisibility)

    let clearedFormat = false
    if (Array.isArray(context.eligible_formats)) {
      clearedFormat = this.replaceFormatOptions(context.eligible_formats)
    }

    this.updateGenreScheme(context.controlled_scheme)
    return clearedFormat
  }

  applySectionVisibility(fieldVisibility) {
    this.element.querySelectorAll("[data-product-section-fields]").forEach((section) => {
      const keys = (section.dataset.productSectionFields || "").split(/\s+/).filter(Boolean)
      if (keys.length === 0) return
      const anyVisible = keys.some((key) => Boolean(fieldVisibility[key]?.visible))
      section.hidden = !anyVisible
      section.setAttribute("aria-hidden", anyVisible ? "false" : "true")
    })
  }

  applyFieldVisibility(fieldKey, visible, isRequired) {
    const shells = this.element.querySelectorAll(`[data-product-field-key="${fieldKey}"]`)
    shells.forEach((shell) => {
      shell.hidden = !visible
      shell.classList.toggle("is-product-field-hidden", !visible)
      shell.dataset.visible = visible ? "true" : "false"
      shell.dataset.required = isRequired ? "true" : "false"
      shell.setAttribute("aria-hidden", visible ? "false" : "true")

      shell.querySelectorAll("input, select, textarea, button").forEach((input) => {
        if (input.dataset.productFieldKeepEnabled === "true") return
        input.disabled = !visible
        if (typeof input.required !== "undefined") {
          input.required = Boolean(visible && isRequired)
        }
      })
    })
  }

  applyFieldLabels(labels) {
    Object.entries(labels).forEach(([key, label]) => {
      if (!label) return
      const shells = this.element.querySelectorAll(`[data-product-field-key="${key}"]`)
      shells.forEach((shell) => {
        const labelEl = shell.querySelector("label.ss-label, .ss-label, label")
        if (labelEl) labelEl.textContent = label
      })
    })
  }

  replaceFormatOptions(formats) {
    if (!this.hasFormatTarget) return false
    const select = this.formatTarget
    const previous = select.value
    const blank = document.createElement("option")
    blank.value = ""
    blank.textContent = "Select format"

    select.innerHTML = ""
    select.appendChild(blank)

    formats.forEach((format) => {
      const option = document.createElement("option")
      option.value = String(format.id)
      option.textContent = format.name
      select.appendChild(option)
    })

    const stillValid = formats.some((format) => String(format.id) === String(previous))
    select.value = stillValid ? previous : ""
    return Boolean(previous) && !stillValid
  }

  updateGenreScheme(schemeKey) {
    if (!schemeKey || !this.hasGenrePickerTarget) return
    if (schemeKey === "bisac") return

    const root = this.genrePickerTarget
    const current =
      root.dataset.genreSubjectsSearchUrlValue ||
      root.getAttribute("data-genre-subjects-search-url-value")
    if (!current) return

    try {
      const next = new URL(current, window.location.origin)
      next.searchParams.set("scheme", schemeKey)
      const nextUrl = `${next.pathname}${next.search}`
      root.dataset.genreSubjectsSearchUrlValue = nextUrl
      root.setAttribute("data-genre-subjects-search-url-value", nextUrl)
    } catch (_error) {
      // Ignore malformed URLs.
    }
  }

  staffItemKindValue() {
    if (!this.hasStaffItemKindTarget) return ""
    return this.staffItemKindTarget.value
  }

  digitalValue() {
    if (!this.hasDigitalTarget) return null
    return this.digitalTarget.checked
  }

  formatValue() {
    if (!this.hasFormatTarget) return ""
    return this.formatTarget.value
  }

  variationTypeValue() {
    if (!this.hasVariationTypeTarget) return ""
    return this.variationTypeTarget.value
  }
}
