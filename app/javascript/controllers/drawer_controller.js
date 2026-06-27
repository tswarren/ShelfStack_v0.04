import { Controller } from "@hotwired/stimulus"
import {
  bindBackdropClose,
  bindOverlayShell,
  cleanupOverlay,
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
    closeOnBackdrop: { type: Boolean, default: true },
    dirtyGuard: { type: Boolean, default: true }
  }

  connect() {
    if (this.element.classList.contains("ss-drawer")) {
      bindOverlayShell(this, {
        lockKind: "drawer",
        panelSelector: ".ss-drawer-panel",
        openedEvent: "drawer:opened",
        closedEvent: "drawer:closed"
      })
      if (this.hasBackdropTarget) bindBackdropClose(this, this.backdropTarget)
    }
  }

  disconnect() {
    if (isOverlayShell(this)) {
      cleanupOverlay(this)
      if (this.hasBackdropTarget) unbindBackdropClose(this, this.backdropTarget)
    }
  }

  open(event) {
    event?.preventDefault()

    const targetId = event?.params?.targetId
    if (targetId) {
      openOverlayById(this.application, "drawer", targetId, event.currentTarget)
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

      const controller = this.application.getControllerForElementAndIdentifier(element, "drawer")
      if (controller && isOverlayShell(controller)) return closeOverlay(controller, { force: true })
      return false
    }

    if (!isOverlayShell(this)) return false

    return closeOverlay(this, { force: true })
  }
}
