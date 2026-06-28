import { Controller } from "@hotwired/stimulus"
import { focusFirstMeaningful } from "shelfstack/focus_trap"
import { restoreFocus } from "shelfstack/focus_restore"

const PANEL_FOCUS_SELECTORS = {
  edit: (lineId) => `#quantity_${lineId}`,
  discount: () => ".ss-pos-line-discount-form [name='discount_reason_id']",
  tax: (lineId) => `#override_tax_category_id_${lineId}`
}

export default class extends Controller {
  static targets = ["displayRow", "editRow", "menu", "panel"]

  connect() {
    this.lastOpener = null
    this.boundOpenLineDiscount = this.openLineDiscount.bind(this)
    this.boundDocumentClick = this.handleDocumentClick.bind(this)
    this.boundCloseMenusOnScroll = this.closeAllMenus.bind(this)
    this.boundMenuKeydown = this.handleMenuKeydown.bind(this)
    document.addEventListener("pos:open-line-discount", this.boundOpenLineDiscount)
    document.addEventListener("click", this.boundDocumentClick)
  }

  disconnect() {
    document.removeEventListener("pos:open-line-discount", this.boundOpenLineDiscount)
    document.removeEventListener("click", this.boundDocumentClick)
    window.removeEventListener("scroll", this.boundCloseMenusOnScroll, true)
    this.menuTargets.forEach((menu) => menu.removeEventListener("keydown", this.boundMenuKeydown))
  }

  toggleMenu(event) {
    event.preventDefault()
    event.stopPropagation()

    const lineId = event.currentTarget.dataset.lineId
    const menu = this.menuForLine(lineId)
    if (!menu) return

    const opening = menu.hidden
    this.closeAllMenus()

    if (opening) {
      this.lastOpener = event.currentTarget
      this.openMenu(menu, event.currentTarget)
    }
  }

  openMenu(menu, button) {
    menu.hidden = false
    menu.classList.add("ss-pos-line-menu--floating")
    menu.style.visibility = "hidden"

    const rect = button.getBoundingClientRect()
    menu.style.minWidth = `${Math.max(rect.width, 192)}px`

    const menuRect = menu.getBoundingClientRect()
    let top = rect.bottom + 4
    if (top + menuRect.height > window.innerHeight - 8) {
      top = Math.max(8, rect.top - menuRect.height - 4)
    }

    let left = rect.right - menuRect.width
    left = Math.max(8, Math.min(left, window.innerWidth - menuRect.width - 8))

    menu.style.top = `${top}px`
    menu.style.left = `${left}px`
    menu.style.visibility = ""

    button.setAttribute("aria-expanded", "true")
    window.addEventListener("scroll", this.boundCloseMenusOnScroll, true)
    menu.addEventListener("keydown", this.boundMenuKeydown)
    menu.querySelector("[role='menuitem']")?.focus()
  }

  handleMenuKeydown(event) {
    if (event.key !== "Escape") return

    event.preventDefault()
    event.stopPropagation()

    const lineId = event.currentTarget.dataset.lineId
    this.closeAllMenus()
    restoreFocus(this.moreButtonForLine(lineId))
  }

  selectPanel(event) {
    event.preventDefault()
    const { lineId, panel } = event.currentTarget.dataset
    this.closeAllMenus()
    this.openPanel(lineId, panel, { opener: this.moreButtonForLine(lineId) })
  }

  cancel(event) {
    event.preventDefault()
    this.collapseLine(event.currentTarget.dataset.lineId, { restoreFocus: true })
  }

  submitPanelForm(event) {
    if (event.key !== "Enter") return
    if (event.target.matches("textarea")) return
    if (event.target.closest("button[type='submit']")) return

    event.preventDefault()
    event.currentTarget.requestSubmit()
  }

  handleKeydown(event) {
    const original = event.detail?.originalEvent
    if (!original || original.key !== "Escape") return

    const lineId = event.currentTarget.dataset.lineId
    const menu = this.menuForLine(lineId)

    if (menu && !menu.hidden) {
      original.preventDefault()
      original.stopPropagation()
      this.closeAllMenus()
      restoreFocus(this.moreButtonForLine(lineId))
      return
    }

    original.preventDefault()
    original.stopPropagation()
    this.collapseLine(lineId, { restoreFocus: true })
  }

  openLineDiscount(event) {
    const lineId = event.detail?.lineId
    if (!lineId) return

    const commandInput = document.querySelector("[data-pos-command-bar-target='input']")
    this.openPanel(lineId, "discount", {
      opener: commandInput,
      focusSelector: ".ss-pos-line-discount-form [name='discount_reason_id']"
    })
  }

  openPanel(lineId, panel, { opener = null, focusSelector = null } = {}) {
    this.hideAllEdits()
    const editRow = this.editRowForLine(lineId)
    if (!editRow) return

    this.lastOpener = opener || this.moreButtonForLine(lineId)
    this.activateEditRow(editRow, lineId, panel)
    this.focusPanelField(editRow, panel, focusSelector)
  }

  focusPanelField(editRow, panel, focusSelector = null) {
    const lineId = editRow.dataset.lineId

    if (focusSelector) {
      const field = editRow.querySelector(focusSelector)
      field?.focus()
      field?.select?.()
      return
    }

    const selectorFn = PANEL_FOCUS_SELECTORS[panel]
    const selector = selectorFn?.(lineId)
    const field = selector ? editRow.querySelector(selector) : null

    if (field) {
      field.focus()
      field.select?.()
      return
    }

    const activePanel = editRow.querySelector(`[data-pos-cart-line-panel="${panel}"]:not([hidden])`)
    const focused = focusFirstMeaningful(activePanel || editRow)
    focused?.select?.()
  }

  collapseLine(lineId, { restoreFocus: shouldRestore = false } = {}) {
    const editRow = this.editRowForLine(lineId)
    if (!editRow) return

    this.closeAllMenus()
    this.deactivateEditRow(editRow, lineId)

    if (shouldRestore) {
      restoreFocus(this.lastOpener) || this.focusCommandInput()
      this.lastOpener = null
    }
  }

  hideAllEdits() {
    this.closeAllMenus()
    this.editRowTargets.forEach((row) => {
      this.deactivateEditRow(row, row.dataset.lineId)
    })
  }

  activateEditRow(editRow, lineId, panel) {
    editRow.hidden = false
    editRow.classList.add("ss-expand-row--active")
    this.setKeyboardScopeActive(editRow, true)
    this.showPanel(editRow, panel)

    const displayRow = this.displayRowForLine(lineId)
    if (displayRow) {
      displayRow.classList.add("ss-pos-cart-line--editing")
    }
  }

  deactivateEditRow(editRow, lineId) {
    editRow.hidden = true
    editRow.classList.remove("ss-expand-row--active")
    this.setKeyboardScopeActive(editRow, false)
    delete editRow.dataset.activePanel

    const displayRow = this.displayRowForLine(lineId)
    if (displayRow) {
      displayRow.classList.remove("ss-pos-cart-line--editing")
    }
  }

  showPanel(editRow, panel) {
    editRow.dataset.activePanel = panel
    editRow.querySelectorAll("[data-pos-cart-line-panel]").forEach((element) => {
      const active = element.dataset.posCartLinePanel === panel
      element.hidden = !active
      element.classList.toggle("ss-pos-line-panel--active", active)
    })
  }

  closeAllMenus() {
    window.removeEventListener("scroll", this.boundCloseMenusOnScroll, true)
    this.menuTargets.forEach((menu) => {
      menu.removeEventListener("keydown", this.boundMenuKeydown)
      menu.hidden = true
      menu.classList.remove("ss-pos-line-menu--floating")
      menu.style.top = ""
      menu.style.left = ""
      menu.style.minWidth = ""
      menu.style.visibility = ""
      this.moreButtonForLine(menu.dataset.lineId)?.setAttribute("aria-expanded", "false")
    })
  }

  handleDocumentClick(event) {
    if (event.target.closest(".ss-pos-line-actions")) return
    this.closeAllMenus()
  }

  menuForLine(lineId) {
    return this.menuTargets.find((menu) => menu.dataset.lineId === String(lineId))
  }

  editRowForLine(lineId) {
    return this.editRowTargets.find((row) => row.dataset.lineId === String(lineId))
  }

  displayRowForLine(lineId) {
    return this.displayRowTargets.find((row) => row.dataset.lineId === String(lineId))
  }

  moreButtonForLine(lineId) {
    return this.displayRowForLine(lineId)?.querySelector("[data-action*='pos-cart-line#toggleMenu']")
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
