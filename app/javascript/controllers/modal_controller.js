import { Controller } from "@hotwired/stimulus"
import {
  bindBackdropClose,
  bindOverlayShell,
  closeOverlay,
  isOverlayShell,
  openOverlayById,
  showOverlay,
  unbindBackdropClose
} from "shelfstack/overlay_shell"

export default class extends Controller {
  static targets = [ "backdrop" ]

  static values = {
    closeOnEscape: { type: Boolean, default: true },
    closeOnBackdrop: { type: Boolean, default: false },
    dirtyGuard: { type: Boolean, default: true }
  }

  connect() {
    if (this.element.classList.contains("ss-modal")) {
      bindOverlayShell(this, {
        lockKind: "modal",
        panelSelector: ".ss-modal-dialog",
        openedEvent: "modal:opened",
        closedEvent: "modal:closed"
      })
      if (this.hasBackdropTarget) bindBackdropClose(this, this.backdropTarget)
    }
  }

  disconnect() {
    if (isOverlayShell(this)) {
      closeOverlay(this)
      if (this.hasBackdropTarget) unbindBackdropClose(this, this.backdropTarget)
    }
  }

  open(event) {
    event?.preventDefault()

    const targetId = event?.params?.targetId
    if (targetId) {
      openOverlayById(this.application, "modal", targetId, event.currentTarget)
      return
    }

    if (!isOverlayShell(this)) return

    this._overlayShell.opener = event?.currentTarget || null
    showOverlay(this)
  }

  close(event) {
    event?.preventDefault()

    const targetId = event?.params?.targetId
    if (targetId) {
      const element = document.getElementById(targetId)
      if (!element) return false

      const controller = this.application.getControllerForElementAndIdentifier(element, "modal")
      if (controller && isOverlayShell(controller)) return closeOverlay(controller)
      return false
    }

    if (!isOverlayShell(this)) return false

    return closeOverlay(this)
  }
}
