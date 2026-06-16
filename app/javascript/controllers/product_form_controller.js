import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["productType", "variationBlock", "variationType", "variant1Label", "variant2Label"]

  connect() {
    this.refresh()
  }

  refresh() {
    this.updateVariationVisibility()
    this.updateLabelVisibility()
  }

  updateVariationVisibility() {
    if (!this.hasProductTypeTarget || !this.hasVariationBlockTarget) return

    const type = this.productTypeTarget.value
    const hideVariation = type === "service" || type === "financial" || type === "non_inventory"
    this.variationBlockTarget.style.display = hideVariation ? "none" : ""
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
