import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const drawerElement = document.querySelector("[data-controller~='item-variant-ops-drawer']")
    if (!drawerElement) {
      this.element.remove()
      return
    }

    const drawerController = this.application.getControllerForElementAndIdentifier(
      drawerElement, "item-variant-ops-drawer"
    )
    drawerController?.resetDemandForm()
    this.element.remove()
  }
}
