import { Controller } from "@hotwired/stimulus"
import { closeOverlay, isOverlayShell } from "shelfstack/overlay_shell"

export default class extends Controller {
  static values = {
    modalId: String
  }

  connect() {
    const element = document.getElementById(this.modalIdValue)
    if (element) {
      const controller = this.application.getControllerForElementAndIdentifier(element, "modal")
      if (controller && isOverlayShell(controller)) {
        closeOverlay(controller, { force: true })
      }
    }
    this.element.remove()
  }
}
