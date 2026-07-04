import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  toggleAll(event) {
    const checked = event.target.checked
    this.element.querySelectorAll(".buyer-workbench-select").forEach((checkbox) => {
      checkbox.checked = checked
    })
  }
}
