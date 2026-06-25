import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["displayRow", "editRow"]

  connect() {
    this.boundOpenLineDiscount = this.openLineDiscount.bind(this)
    document.addEventListener("pos:open-line-discount", this.boundOpenLineDiscount)
  }

  disconnect() {
    document.removeEventListener("pos:open-line-discount", this.boundOpenLineDiscount)
  }

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

  openLineDiscount(event) {
    const lineId = event.detail?.lineId
    if (!lineId) return

    this.hideAllEdits()
    const editRow = this.editRowTargets.find((row) => row.dataset.lineId === lineId)
    if (!editRow) return

    editRow.hidden = false
    const displayRow = this.displayRowTargets.find((row) => row.dataset.lineId === lineId)
    if (displayRow) displayRow.hidden = true

    const discountField = editRow.querySelector(".ss-pos-line-discount-form [name='discount_value']")
    discountField?.focus()
    discountField?.select()
  }

  hideAllEdits() {
    this.editRowTargets.forEach((row) => { row.hidden = true })
    this.displayRowTargets.forEach((row) => { row.hidden = false })
  }
}
