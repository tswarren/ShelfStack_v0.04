import { Controller } from "@hotwired/stimulus"
import { parseIntField, unitCostCents, discountBpsFromCost } from "purchasing/vendor_cost"

export default class extends Controller {
  static targets = [
    "lookupInput",
    "variantId",
    "purchaseOrderLineId",
    "message",
    "choices",
    "title",
    "vendorItem",
    "onHand",
    "onOrder",
    "tboQty",
    "returnability",
    "quantityOrdered",
    "quantityExpected",
    "quantityReceived",
    "quantityAccepted",
    "listPrice",
    "discountBps",
    "unitCost",
    "creditAmount",
    "warnings"
  ]

  static values = {
    url: String,
    context: String,
    vendorFieldId: String,
    purchaseOrderFieldId: String,
    quantityField: String,
    requireEligible: { type: Boolean, default: false }
  }

  connect() {
    if (this.hasVariantIdTarget && this.variantIdTarget.value) {
      this.element.dataset.blankRow = "false"
      if (this.hasLookupInputTarget && !this.lookupInputTarget.value) {
        this.lookupInputTarget.value = this.element.dataset.purchasingLineRowInitialSkuValue || ""
      }
      if (this.hasTitleTarget && !this.titleTarget.textContent) {
        this.titleTarget.textContent = this.element.dataset.purchasingLineRowInitialLabelValue || ""
      }
    }
  }

  lookupExact(event) {
    if (event.type === "keydown" && event.key !== "Enter") return
    if (event.type === "keydown") event.preventDefault()

    this.clearChoices()
    const query = this.lookupInputTarget.value.trim()
    if (!query) {
      this.clearSelection("Enter a SKU, vendor item number, or barcode.")
      return
    }

    this.fetchLookup({ q: query, mode: "exact" })
  }

  search() {
    const query = this.lookupInputTarget.value.trim()
    if (query.length < 2) {
      this.clearChoices()
      return
    }

    this.fetchLookup({ q: query, mode: "search" })
  }

  quantityKeydown(event) {
    if (event.key !== "Enter") return
    event.preventDefault()
    if (!this.variantIdTarget?.value) return

    this.element.dataset.blankRow = "false"
    const quantity = event.target.value
    this.dispatchCommitted(quantity)
  }

  fetchLookup(params) {
    const lookupUrl = new URL(this.urlValue, window.location.origin)
    Object.entries(params).forEach(([key, value]) => lookupUrl.searchParams.set(key, value))
    lookupUrl.searchParams.set("context", this.contextValue || "order")

    const vendorId = this.vendorIdFromForm()
    if (vendorId) lookupUrl.searchParams.set("vendor_id", vendorId)

    const purchaseOrderId = this.purchaseOrderIdFromForm()
    if (purchaseOrderId) lookupUrl.searchParams.set("purchase_order_id", purchaseOrderId)

    fetch(lookupUrl)
      .then((response) => response.json())
      .then((data) => this.renderResult(data))
      .catch(() => {
        this.messageTarget.textContent = "Unable to look up line right now."
        this.messageTarget.className = "ss-hint ss-hint--warning"
      })
  }

  renderResult(data) {
    if (this.hasMessageTarget) {
      this.messageTarget.textContent = data.message || ""
      this.messageTarget.className = data.message ? "ss-hint ss-hint--warning" : "ss-hint"
    }

    const matches = data.matches || []

    if (data.status === "found") {
      this.selectMatch(matches[0])
      return
    }

    if (data.status === "ineligible") {
      this.clearSelection(data.message)
      return
    }

    if (data.status === "ambiguous" || data.status === "search") {
      this.renderChoices(matches)
      this.clearSelection(null)
      return
    }

    this.clearSelection(data.message)
  }

  renderChoices(matches) {
    if (!this.hasChoicesTarget) return
    this.choicesTarget.innerHTML = ""
    matches.forEach((match) => {
      const button = document.createElement("button")
      button.type = "button"
      button.className = "ss-btn ss-btn-secondary ss-variant-choice"
      button.textContent = this.matchLabel(match)
      button.addEventListener("click", () => this.selectMatch(match))
      this.choicesTarget.appendChild(button)
    })
  }

  selectMatch(match) {
    if (this.requireEligibleValue && !match.eligible) {
      this.clearSelection(`Variant ${match.sku} is not inventory-eligible (${match.inventory_behavior}).`)
      this.clearChoices()
      return
    }

    this.element.dataset.blankRow = "false"
    if (this.hasVariantIdTarget) this.variantIdTarget.value = match.id
    if (this.hasPurchaseOrderLineIdTarget && match.purchase_order_line_id) {
      this.purchaseOrderLineIdTarget.value = match.purchase_order_line_id
      this.element.dataset.mergeAllowed = "false"
    }
    if (this.hasLookupInputTarget) this.lookupInputTarget.value = match.sku

    this.updateDisplays(match)
    this.applyPricingDefaults(match)
    this.applyQuantityDefaults(match)
    this.updateWarnings(match)
    this.clearChoices()

    if (this.hasMessageTarget) {
      this.messageTarget.textContent = ""
      this.messageTarget.className = "ss-hint"
    }

    const qtyInput = this.quantityInput()
    qtyInput?.focus()
    qtyInput?.select()
  }

  updateDisplays(match) {
    if (this.hasTitleTarget) {
      this.titleTarget.textContent = `${match.name}${match.condition ? ` (${match.condition})` : ""}`
    }
    if (this.hasVendorItemTarget) this.vendorItemTarget.textContent = match.vendor_item_number || "—"
    if (this.hasOnHandTarget) this.onHandTarget.textContent = match.quantity_on_hand ?? 0
    if (this.hasOnOrderTarget) this.onOrderTarget.textContent = match.quantity_on_order ?? 0
    if (this.hasTboQtyTarget) this.tboQtyTarget.textContent = match.open_tbo_quantity ?? 0
    if (this.hasReturnabilityTarget) this.returnabilityTarget.textContent = match.returnability_status || "—"
  }

  applyPricingDefaults(match) {
    if (this.hasListPriceTarget && !this.listPriceTarget.value && match.unit_list_price_cents != null) {
      this.listPriceTarget.value = match.unit_list_price_cents
    }
    if (this.hasDiscountBpsTarget && !this.discountBpsTarget.value && match.supplier_discount_bps != null) {
      this.discountBpsTarget.value = match.supplier_discount_bps
    }
    if (this.hasUnitCostTarget && !this.unitCostTarget.value && match.unit_cost_cents != null) {
      this.unitCostTarget.value = match.unit_cost_cents
    }
    if (this.hasCreditAmountTarget && !this.creditAmountTarget.value && match.unit_cost_cents != null) {
      const qty = parseInt(this.quantityInput()?.value, 10) || 1
      this.creditAmountTarget.value = match.unit_cost_cents * qty
    }

    this.recalculatePricingFromListAndDiscount()
    this.syncCreditFromCostAndQuantity()
  }

  applyQuantityDefaults(match) {
    if (this.hasQuantityExpectedTarget && match.quantity_expected != null && !this.quantityExpectedTarget.value) {
      this.quantityExpectedTarget.value = match.quantity_expected
    }
    if (this.hasQuantityReceivedTarget && match.quantity_expected != null && !this.quantityReceivedTarget.value) {
      this.quantityReceivedTarget.value = match.quantity_expected
    }
    if (this.hasQuantityAcceptedTarget && match.quantity_expected != null && !this.quantityAcceptedTarget.value) {
      this.quantityAcceptedTarget.value = match.quantity_expected
    }
    if (this.hasQuantityOrderedTarget && !this.quantityOrderedTarget.value) {
      this.quantityOrderedTarget.value = 1
    }
  }

  updateWarnings(match) {
    if (!this.hasWarningsTarget) return
    const warnings = []
    if (!match.sourcing_record_present) warnings.push("No vendor source")
    if (match.returnability_status === "non_returnable") warnings.push("Non-returnable")
    this.warningsTarget.textContent = warnings.join(" · ")
  }

  dispatchCommitted(quantity) {
    this.dispatch("committed", {
      detail: {
        variantId: this.variantIdTarget?.value,
        quantity,
        mergeAllowed: this.element.dataset.mergeAllowed !== "false"
      },
      bubbles: true
    })
  }

  quantityInput() {
    if (this.hasQuantityOrderedTarget) return this.quantityOrderedTarget
    if (this.hasQuantityReceivedTarget) return this.quantityReceivedTarget
    if (this.quantityFieldValue) {
      return this.element.querySelector(`[name*='[${this.quantityFieldValue}]']`)
    }
    return null
  }

  quantityChanged() {
    this.syncCreditFromCostAndQuantity()
    this.dispatchRecalculate()
  }

  pricingFieldChanged(event) {
    if (this.pricingRecalcLock) return

    const field = event.target
    const list = parseIntField(this.listPriceTarget?.value)
    const discount = parseIntField(this.discountBpsTarget?.value)
    const cost = parseIntField(this.unitCostTarget?.value)

    this.pricingRecalcLock = true
    if (field === this.listPriceTarget || field === this.discountBpsTarget) {
      if (list != null && this.hasUnitCostTarget) {
        const calculated = unitCostCents(list, discount ?? 0)
        this.unitCostTarget.value = calculated ?? ""
      }
    } else if (field === this.unitCostTarget && list > 0 && cost != null && this.hasDiscountBpsTarget) {
      const calculated = discountBpsFromCost(list, cost)
      if (calculated != null) this.discountBpsTarget.value = calculated
    }
    this.pricingRecalcLock = false

    this.dispatchRecalculate()
  }

  creditDriverChanged() {
    this.syncCreditFromCostAndQuantity()
    this.dispatchRecalculate()
  }

  creditAmountChanged() {
    this.dispatchRecalculate()
  }

  recalculatePricingFromListAndDiscount() {
    if (!this.hasListPriceTarget || !this.hasUnitCostTarget) return

    const list = parseIntField(this.listPriceTarget.value)
    if (list == null) return

    const discount = parseIntField(this.discountBpsTarget?.value) ?? 0
    this.pricingRecalcLock = true
    const calculated = unitCostCents(list, discount)
    if (calculated != null) this.unitCostTarget.value = calculated
    this.pricingRecalcLock = false
  }

  syncCreditFromCostAndQuantity() {
    if (!this.hasCreditAmountTarget || !this.hasUnitCostTarget) return

    const cost = parseIntField(this.unitCostTarget.value)
    const qty = parseIntField(this.quantityInput()?.value) ?? 1
    if (cost == null) return

    this.creditAmountTarget.value = cost * qty
  }

  dispatchRecalculate() {
    this.element.dispatchEvent(new CustomEvent("purchasing-line-table:recalculate", { bubbles: true }))
  }

  vendorIdFromForm() {
    if (!this.hasVendorFieldIdValue) return null
    return document.getElementById(this.vendorFieldIdValue)?.value || null
  }

  purchaseOrderIdFromForm() {
    if (!this.hasPurchaseOrderFieldIdValue) return null
    return document.getElementById(this.purchaseOrderFieldIdValue)?.value || null
  }

  matchLabel(match) {
    const condition = match.condition ? ` (${match.condition})` : ""
    return `${match.sku} — ${match.name}${condition}`
  }

  clearSelection(message) {
    if (this.hasVariantIdTarget) this.variantIdTarget.value = ""
    if (this.hasTitleTarget) this.titleTarget.textContent = ""
    if (message && this.hasMessageTarget) {
      this.messageTarget.textContent = message
      this.messageTarget.className = "ss-hint ss-hint--warning"
    }
  }

  clearChoices() {
    if (this.hasChoicesTarget) this.choicesTarget.innerHTML = ""
  }
}
