import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["subDepartment", "displayLocation"]
  static values = {
    defaultsUrl: String
  }

  changed(event) {
    const storeCategoryId = event.target.value
    if (!storeCategoryId) return

    const url = new URL(this.defaultsUrlValue, window.location.origin)
    url.searchParams.set("store_category_id", storeCategoryId)

    fetch(url, { headers: { Accept: "application/json" } })
      .then((response) => response.json())
      .then((data) => {
        if (this.hasSubDepartmentTarget && data.default_sub_department_id) {
          this.subDepartmentTarget.value = data.default_sub_department_id
        }
        if (this.hasDisplayLocationTarget && data.default_display_location_id) {
          this.displayLocationTarget.value = data.default_display_location_id
        }
      })
      .catch(() => {})
  }
}
