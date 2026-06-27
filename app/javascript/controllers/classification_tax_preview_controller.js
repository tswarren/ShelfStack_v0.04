import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "subDepartment" ]
  static values = { url: String }

  refresh() {
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("sub_department_id", this.subDepartmentTarget.value)
    const frame = document.getElementById("classification-tax-preview-frame")
    if (frame) frame.src = url.toString()
  }
}
