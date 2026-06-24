import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { nextLineId: Number }

  connect() {
    this.element.addEventListener("keydown", this.handleKeydown)
  }

  disconnect() {
    this.element.removeEventListener("keydown", this.handleKeydown)
  }

  handleKeydown = (event) => {
    const tag = event.target.tagName.toLowerCase()
    const typing = tag === "input" || tag === "textarea" || tag === "select"

    if (event.key === "/" && !typing) {
      event.preventDefault()
      this.focusIntake()
      return
    }

    if (event.key.toLowerCase() === "n" && !typing && !event.metaKey && !event.ctrlKey) {
      event.preventDefault()
      this.goToNextLine()
      return
    }

    if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "k") {
      event.preventDefault()
      this.focusIntake()
    }
  }

  focusIntake() {
    const field = this.element.querySelector("[data-buyback-intake-target='identifier']")
    if (field) {
      field.focus()
      field.select()
      const panel = document.getElementById("intake-panel")
      if (panel) panel.scrollIntoView({ behavior: "smooth", block: "start" })
    }
  }

  goToNextLine() {
    const lineId = this.nextLineIdValue
    if (!lineId) return
    const target = document.getElementById(`line-${lineId}`)
    if (target) {
      target.scrollIntoView({ behavior: "smooth", block: "center" })
      target.classList.add("ss-buyback-row--highlight")
      window.setTimeout(() => target.classList.remove("ss-buyback-row--highlight"), 2000)
    }
  }
}
