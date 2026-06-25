import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["productType", "variationBlock", "variationType", "variant1Label", "variant2Label"]

  connect() {
    this.refresh()
  }

  refresh() {
    this.updateLabelVisibility()
  }

  updateLabelVisibility() {
    if (!this.hasVariationTypeTarget) return

    const variationType = this.variationTypeTarget.value
    const variant1Wrap = this.hasVariant1LabelTarget ? this.variant1LabelTarget.closest(".ss-field") : null
    const variant2Wrap = this.hasVariant2LabelTarget ? this.variant2LabelTarget.closest(".ss-field") : null

    if (variant1Wrap) {
      variant1Wrap.style.display = variationType === "variable" || variationType === "matrix" ? "" : "none"
    }
    if (variant2Wrap) {
      variant2Wrap.style.display = variationType === "matrix" ? "" : "none"
    }
  }
}
