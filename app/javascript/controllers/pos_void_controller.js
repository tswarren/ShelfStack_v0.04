import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "reasonField", "notesField", "form"]

  open(event) {
    event.preventDefault()
    this.modalTarget.hidden = false
    if (this.hasReasonFieldTarget) this.reasonFieldTarget.focus()
  }

  close(event) {
    if (event) event.preventDefault()
    this.modalTarget.hidden = true
  }

  submit(event) {
    if (!this.hasReasonFieldTarget || !this.reasonFieldTarget.value) {
      event.preventDefault()
      alert("Select a void reason before continuing.")
    }
  }
}
