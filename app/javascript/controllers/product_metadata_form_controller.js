import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sectionsFrame", "staffItemKind", "digital", "format"]
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

    return false
  }

  reloadSections() {
    if (!this.hasSectionsFrameTarget || !this.hasPreviewUrlValue) return

    const frame = this.sectionsFrameTarget.querySelector("turbo-frame#product_metadata_sections")
    if (!frame) return

    const url = new URL(this.previewUrlValue, window.location.origin)
    const namespace = this.namespaceValue

    if (this.hasStaffItemKindTarget) {
      url.searchParams.set(`${namespace}[staff_item_kind]`, this.staffItemKindTarget.value)
    }

    if (this.hasDigitalTarget) {
      url.searchParams.set(`${namespace}[digital]`, this.digitalTarget.checked ? "1" : "0")
    }

    if (this.hasFormatTarget && this.formatTarget.value) {
      url.searchParams.set(`${namespace}[format_id]`, this.formatTarget.value)
    }

    frame.src = url.toString()
  }
}
