import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["displayRow", "editRow"]

  edit(event) {
    event.preventDefault()
    const lineId = event.currentTarget.dataset.lineId
    this.hideAllEdits()
    const editRow = this.editRowTargets.find((row) => row.dataset.lineId === lineId)
    if (editRow) {
      editRow.hidden = false
      const displayRow = this.displayRowTargets.find((row) => row.dataset.lineId === lineId)
      if (displayRow) displayRow.hidden = true
    }
  }

  cancel(event) {
    event.preventDefault()
    const lineId = event.currentTarget.dataset.lineId
    const editRow = this.editRowTargets.find((row) => row.dataset.lineId === lineId)
    const displayRow = this.displayRowTargets.find((row) => row.dataset.lineId === lineId)
    if (editRow) editRow.hidden = true
    if (displayRow) displayRow.hidden = false
  }

  hideAllEdits() {
    this.editRowTargets.forEach((row) => { row.hidden = true })
    this.displayRowTargets.forEach((row) => { row.hidden = false })
  }
}
