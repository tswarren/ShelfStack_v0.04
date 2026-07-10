import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sectionsFrame", "staffItemKind", "digital", "format", "variationType"]
  static values = {
    previewUrl: String,
    namespace: String
  }

  connect() {
    this.refreshTimeout = null
  }

  disconnect() {
    if (this.refreshTimeout) clearTimeout(this.refreshTimeout)
  }

  itemKindChanged() {
    this.scheduleReload()
  }

  refresh(event) {
    if (!this.shouldRefresh(event?.target)) return
    this.scheduleReload()
  }

  scheduleReload() {
    clearTimeout(this.refreshTimeout)
    this.refreshTimeout = setTimeout(() => this.reloadSections(), 100)
  }

  shouldRefresh(target) {
    if (!target || !this.hasPreviewUrlValue) return false

    if (this.hasDigitalTarget && target === this.digitalTarget) return true
    if (this.hasFormatTarget && target === this.formatTarget) return true
    if (this.hasVariationTypeTarget && target === this.variationTypeTarget) return true

    return false
  }

  reloadSections() {
    const form = this.element.closest("form")
    if (!form || !this.hasSectionsFrameTarget || !this.hasPreviewUrlValue) return

    const frame = this.sectionsFrameTarget.querySelector("turbo-frame#product_metadata_sections")
    if (!frame) return

    const url = new URL(this.previewUrlValue, window.location.origin)
    const formData = new FormData(form)

    for (const [key, value] of formData.entries()) {
      if (value instanceof File) continue
      url.searchParams.append(key, value.toString())
    }

    frame.src = url.toString()
  }
}
