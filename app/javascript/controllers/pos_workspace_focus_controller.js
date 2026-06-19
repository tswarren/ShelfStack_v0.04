import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.querySelector("[data-pos-command-bar-target='input']")?.focus()
  }
}
