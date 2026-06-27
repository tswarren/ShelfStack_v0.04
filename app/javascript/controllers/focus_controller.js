import { Controller } from "@hotwired/stimulus"
import { restoreFocus, resolveFocusRestoreId } from "shelfstack/focus_restore"

export default class extends Controller {
  static values = {
    restoreId: String
  }

  restore(event) {
    event?.preventDefault()

    const byId = resolveFocusRestoreId(this.restoreIdValue)
    if (restoreFocus(byId)) return

    const stored = this.element.dataset.focusOpenerId
    if (stored) restoreFocus(document.getElementById(stored))
  }

  rememberOpener(event) {
    const opener = event?.currentTarget
    if (!opener?.id) return

    this.element.dataset.focusOpenerId = opener.id
  }
}
