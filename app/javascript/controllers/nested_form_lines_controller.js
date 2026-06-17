import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "template", "line", "destroy"]

  addLine(event) {
    event.preventDefault()
    const content = this.templateTarget.content.cloneNode(true)
    const index = Date.now().toString()
    content.querySelectorAll("[name]").forEach((element) => {
      element.name = element.name.replace(/NEW_RECORD/g, index)
      element.id = element.id?.replace(/NEW_RECORD/g, index)
    })
    content.querySelectorAll("[for]").forEach((element) => {
      element.htmlFor = element.htmlFor.replace(/NEW_RECORD/g, index)
    })
    this.containerTarget.appendChild(content)
  }

  removeLine(event) {
    event.preventDefault()
    const line = event.target.closest("[data-nested-form-lines-target='line']")
    if (!line) return

    const destroyField = line.querySelector("[data-nested-form-lines-target='destroy']")
    if (destroyField) {
      destroyField.value = "1"
      line.hidden = true
    } else {
      line.remove()
    }
  }
}
