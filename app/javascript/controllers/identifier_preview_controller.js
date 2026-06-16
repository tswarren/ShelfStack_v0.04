import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["identifierType", "identifierValue", "normalized", "validation"]
  static values = { url: String }

  connect() {
    this.refresh()
  }

  refresh() {
    const identifierType = this.identifierTypeTarget.value
    const value = this.identifierValueTarget.value

    if (!value.trim()) {
      this.normalizedTarget.textContent = "—"
      this.clearValidation()
      return
    }

    const previewUrl = new URL(this.urlValue, window.location.origin)
    previewUrl.searchParams.set("identifier_type", identifierType)
    previewUrl.searchParams.set("value", value)

    fetch(previewUrl)
      .then((response) => response.json())
      .then((data) => this.renderPreview(data))
      .catch(() => {
        this.validationTarget.textContent = "Unable to validate identifier right now."
        this.validationTarget.className = "ss-hint ss-hint--warning"
      })
  }

  renderPreview(data) {
    this.normalizedTarget.textContent = data.normalized || "—"
    this.clearValidation()

    if (data.message) {
      this.validationTarget.textContent = data.message
      this.validationTarget.className = "ss-hint ss-hint--warning"
    } else if (data.valid === true) {
      this.validationTarget.textContent = "Check digit valid."
      this.validationTarget.className = "ss-hint ss-hint--success"
    }
  }

  clearValidation() {
    this.validationTarget.textContent = ""
    this.validationTarget.className = "ss-hint"
  }
}
