import { Controller } from "@hotwired/stimulus"
import { focusFirstMeaningful } from "shelfstack/focus_trap"
import { restoreFocus } from "shelfstack/focus_restore"

export default class extends Controller {
  static targets = ["displayRow", "editRow"]

  connect() {
    this.lastOpener = null
    this.boundOpenLineDiscount = this.openLineDiscount.bind(this)
    document.addEventListener("pos:open-line-discount", this.boundOpenLineDiscount)
  }

  disconnect() {
    document.removeEventListener("pos:open-line-discount", this.boundOpenLineDiscount)
  }

  edit(event) {
    event.preventDefault()
    const lineId = event.currentTarget.dataset.lineId
    this.openEdit(lineId, event.currentTarget)
  }

  cancel(event) {
    event.preventDefault()
    this.collapseLine(event.currentTarget.dataset.lineId, { restoreFocus: true })
  }

  handleKeydown(event) {
    const original = event.detail?.originalEvent
    if (!original || original.key !== "Escape") return

    original.preventDefault()
    original.stopPropagation()
    this.collapseLine(event.currentTarget.dataset.lineId, { restoreFocus: true })
  }

  openLineDiscount(event) {
    const lineId = event.detail?.lineId
    if (!lineId) return

    const commandInput = document.querySelector("[data-pos-command-bar-target='input']")
    this.openEdit(lineId, commandInput, {
      focusSelector: ".ss-pos-line-discount-form [name='discount_value']"
    })
  }

  openEdit(lineId, opener = null, { focusSelector = null } = {}) {
    this.hideAllEdits()
    const editRow = this.editRowForLine(lineId)
    if (!editRow) return

    this.lastOpener = opener || this.moreButtonForLine(lineId)
    this.activateEditRow(editRow, lineId)

    if (focusSelector) {
      const field = editRow.querySelector(focusSelector)
      field?.focus()
      field?.select?.()
      return
    }

    const focusRoot = editRow.querySelector(".ss-row-detail") || editRow
    focusFirstMeaningful(focusRoot)
  }

  collapseLine(lineId, { restoreFocus: shouldRestore = false } = {}) {
    const editRow = this.editRowForLine(lineId)
    if (!editRow) return

    this.deactivateEditRow(editRow, lineId)

    if (shouldRestore) {
      restoreFocus(this.lastOpener) || this.focusCommandInput()
      this.lastOpener = null
    }
  }

  hideAllEdits() {
    this.editRowTargets.forEach((row) => {
      this.deactivateEditRow(row, row.dataset.lineId)
    })
  }

  activateEditRow(editRow, lineId) {
    editRow.hidden = false
    editRow.classList.add("ss-expand-row--active")
    this.setKeyboardScopeActive(editRow, true)

    const displayRow = this.displayRowForLine(lineId)
    if (displayRow) {
      displayRow.classList.add("ss-pos-cart-line--editing")
      const moreButton = this.moreButtonForLine(lineId)
      if (moreButton) moreButton.setAttribute("aria-expanded", "true")
    }
  }

  deactivateEditRow(editRow, lineId) {
    editRow.hidden = true
    editRow.classList.remove("ss-expand-row--active")
    this.setKeyboardScopeActive(editRow, false)

    const displayRow = this.displayRowForLine(lineId)
    if (displayRow) {
      displayRow.classList.remove("ss-pos-cart-line--editing")
      const moreButton = this.moreButtonForLine(lineId)
      if (moreButton) moreButton.setAttribute("aria-expanded", "false")
    }
  }

  editRowForLine(lineId) {
    return this.editRowTargets.find((row) => row.dataset.lineId === String(lineId))
  }

  displayRowForLine(lineId) {
    return this.displayRowTargets.find((row) => row.dataset.lineId === String(lineId))
  }

  moreButtonForLine(lineId) {
    return this.displayRowForLine(lineId)?.querySelector("[data-action*='pos-cart-line#edit']")
  }

  setKeyboardScopeActive(editRow, active) {
    editRow.dataset.keyboardScopeActiveValue = active ? "true" : "false"
    const scope = this.application.getControllerForElementAndIdentifier(editRow, "keyboard-scope")
    if (scope) scope.activeValue = active
  }

  focusCommandInput() {
    document.querySelector("[data-pos-command-bar-target='input']")?.focus()
  }
}
