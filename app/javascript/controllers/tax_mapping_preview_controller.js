import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["store", "taxCategory", "storeTaxRate", "effectiveOn", "output"]
  static values = {
    stores: Array,
    taxCategories: Array,
    storeTaxRates: Array
  }

  update() {
    const storeId = parseInt(this.storeTarget.value, 10)
    const taxCategoryId = parseInt(this.taxCategoryTarget.value, 10)
    const rateId = parseInt(this.storeTaxRateTarget.value, 10)
    const effectiveOn = this.hasEffectiveOnTarget ? this.effectiveOnTarget.value : ""

    const store = this.storesValue.find((s) => s.id === storeId)
    const taxCategory = this.taxCategoriesValue.find((c) => c.id === taxCategoryId)
    const rate = this.storeTaxRatesValue.find((r) => r.id === rateId)

    if (!store || !taxCategory || !rate) {
      this.outputTarget.innerHTML = "<strong>Preview:</strong> Select store, tax category, and tax rate to preview this mapping."
      return
    }

    const percent = isNaN(rate.bps) ? "—" : `${(rate.bps / 100.0).toFixed(2)}%`
    const effective = effectiveOn || "the effective date"
    this.outputTarget.innerHTML = `<strong>Preview:</strong> For ${store.label}, ${taxCategory.name} will use ${rate.name} (${percent}) beginning ${effective}.`
  }
}
