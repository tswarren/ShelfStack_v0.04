import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["backdrop", "panel", "body", "title", "frame"]

  connect() {
    this.element.addEventListener("keydown", this.handleKeydown)
    this.element.addEventListener("turbo:submit-end", this.handleSubmitEnd)
    this.openLineFromQuery()
    this.openLineFromStreamMarker()
  }

  disconnect() {
    this.element.removeEventListener("keydown", this.handleKeydown)
    this.element.removeEventListener("turbo:submit-end", this.handleSubmitEnd)
  }

  handleKeydown = (event) => {
    if (event.key === "Escape" && !this.panelTarget.hidden) {
      this.close()
    }
  }

  handleSubmitEnd = (event) => {
    if (!event.detail?.success) return

    window.requestAnimationFrame(() => this.openLineFromStreamMarker())
  }

  open(event) {
    const button = event.currentTarget
    const detailUrl = button.dataset.detailUrl
    if (!detailUrl) return

    this.titleTarget.textContent = button.dataset.lineTitle || "Work item"
    this.frameTarget.src = detailUrl
    this.backdropTarget.hidden = false
    this.panelTarget.hidden = false
    document.body.classList.add("ss-drawer-open")
  }

  openLine(lineId, title) {
    const button = this.element.querySelector(`[data-line-id="${lineId}"]`)
    if (!button) return

    this.titleTarget.textContent = title || button.dataset.lineTitle || "Work item"
    this.frameTarget.src = button.dataset.detailUrl
    this.backdropTarget.hidden = false
    this.panelTarget.hidden = false
    document.body.classList.add("ss-drawer-open")
  }

  close() {
    this.backdropTarget.hidden = true
    this.panelTarget.hidden = true
    if (this.hasFrameTarget) {
      this.frameTarget.removeAttribute("src")
      const content = this.frameTarget.querySelector("#buyback-line-detail-content")
      if (content) {
        content.innerHTML = "<p class=\"ss-muted\">Select a work item to view details.</p>"
      }
    }
    document.body.classList.remove("ss-drawer-open")
  }

  openLineFromQuery() {
    const params = new URLSearchParams(window.location.search)
    const lineId = params.get("open_line")
    if (!lineId) return

    window.requestAnimationFrame(() => this.openLine(lineId))
  }

  openLineFromStreamMarker() {
    const marker = this.element.querySelector("[data-buyback-open-line]")
    if (!marker) return

    const lineId = marker.dataset.buybackOpenLine
    marker.remove()
    window.requestAnimationFrame(() => this.openLine(lineId))
  }
}
