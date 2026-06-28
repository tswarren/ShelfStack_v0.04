import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  close(event) {
    this.element.removeAttribute("open")
  }
}
