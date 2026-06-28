import { Controller } from "@hotwired/stimulus"

const INPUT_LIKE = "input, textarea, select, [contenteditable='true']"

export default class extends Controller {
  static values = {
    active: { type: Boolean, default: true }
  }

  connect() {
    this.handleKeydown = this.handleKeydown.bind(this)
    this.element.addEventListener("keydown", this.handleKeydown)
  }

  disconnect() {
    this.element.removeEventListener("keydown", this.handleKeydown)
  }

  handleKeydown(event) {
    if (!this.activeValue) return
    if (this.shouldIgnoreEvent(event)) return

    this.element.dispatchEvent(new CustomEvent("keyboard-scope:keydown", {
      bubbles: true,
      detail: { originalEvent: event }
    }))
  }

  shouldIgnoreEvent(event) {
    const target = event.target
    if (!(target instanceof HTMLElement)) return false
    if (!target.matches(INPUT_LIKE)) return false

    if (event.key === "Escape") return false

    if (target.matches("textarea") && event.key === "Enter" && !event.metaKey && !event.ctrlKey) {
      return true
    }

    return true
  }
}
