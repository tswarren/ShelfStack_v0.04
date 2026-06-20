import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    document.dispatchEvent(new CustomEvent("pos:workspace-updated"))
    this.element.querySelector("[data-pos-command-bar-target='input']")?.focus()
  }
}
