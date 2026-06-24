import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["backdrop", "panel", "body", "title"]

  connect() {
    this.element.addEventListener("keydown", this.handleKeydown)
  }

  disconnect() {
    this.element.removeEventListener("keydown", this.handleKeydown)
  }

  handleKeydown = (event) => {
    if (event.key === "Escape" && !this.panelTarget.hidden) {
      this.close()
    }
  }

  open(event) {
    const button = event.currentTarget
    const lineId = button.dataset.lineId
    const template = document.getElementById(`buyback-line-panel-${lineId}`)
    if (!template) return

    this.titleTarget.textContent = button.dataset.lineTitle || "Work item"
    this.bodyTarget.innerHTML = ""
    this.bodyTarget.appendChild(template.content.cloneNode(true))
    this.backdropTarget.hidden = false
    this.panelTarget.hidden = false
    document.body.classList.add("ss-drawer-open")
  }

  close() {
    this.backdropTarget.hidden = true
    this.panelTarget.hidden = true
    this.bodyTarget.innerHTML = ""
    document.body.classList.remove("ss-drawer-open")
  }
}
