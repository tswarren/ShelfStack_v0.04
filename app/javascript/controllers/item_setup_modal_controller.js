import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "title",
    "identifierValueField",
    "identifierTypeField",
    "primaryField",
    "variantIdField",
    "priceField",
    "productVendorIdField",
    "variantVendorIdField",
    "vendorItemNumberField",
    "supplierDiscountField",
    "returnabilityField",
    "preferredField",
    "subDepartmentField"
  ]

  prepareIdentifierCreate(_event) {
    this.resetIdentifierForm()
    if (this.hasTitleTarget) this.titleTarget.textContent = "Add identifier"
  }

  prepareIdentifierEdit(event) {
    const button = event.currentTarget
    if (this.hasIdentifierValueFieldTarget) {
      this.identifierValueFieldTarget.value = button.dataset.identifierValue || ""
    }
    if (this.hasIdentifierTypeFieldTarget) {
      this.identifierTypeFieldTarget.value = button.dataset.identifierType || "isbn13"
      this.identifierTypeFieldTarget.disabled = true
    }
    if (this.hasPrimaryFieldTarget) {
      this.primaryFieldTarget.checked = button.dataset.primary === "true"
    }
    const form = this.element.querySelector("#item-identifier-modal form")
    if (form) {
      form.action = button.dataset.updateUrl || form.dataset.createUrl
      form.querySelector("[name='_method']")?.remove()
      if (button.dataset.updateUrl) {
        const method = document.createElement("input")
        method.type = "hidden"
        method.name = "_method"
        method.value = "patch"
        form.appendChild(method)
      }
    }
    if (this.hasTitleTarget) this.titleTarget.textContent = "Edit identifier"
  }

  preparePriceEdit(event) {
    const button = event.currentTarget
    if (this.hasVariantIdFieldTarget) {
      this.variantIdFieldTarget.value = button.dataset.variantId || ""
    }
    if (this.hasPriceFieldTarget) {
      this.priceFieldTarget.value = button.dataset.priceCents || ""
    }
    const form = this.element.querySelector("#item-price-modal form")
    if (form && button.dataset.variantId) {
      form.action = `/items/setup_modals/variants/${button.dataset.variantId}/price`
    }
    if (this.hasTitleTarget) {
      this.titleTarget.textContent = `Edit price — ${button.dataset.variantSku || "SKU"}`
    }
  }

  prepareProductVendorCreate(_event) {
    if (this.hasTitleTarget) this.titleTarget.textContent = "Add product vendor"
  }

  prepareProductVendorEdit(event) {
    const button = event.currentTarget
    this.populateVendorFields(button)
    const form = this.element.querySelector("#item-product-vendor-modal form")
    if (form && button.dataset.updateUrl) {
      form.action = button.dataset.updateUrl
      this.ensurePatchMethod(form)
    }
    if (this.hasTitleTarget) {
      this.titleTarget.textContent = button.dataset.modalTitle || "Edit product vendor"
    }
  }

  prepareVariantVendorCreate(event) {
    const button = event.currentTarget
    if (this.hasVariantIdFieldTarget) {
      this.variantIdFieldTarget.value = button.dataset.variantId || ""
    }
    const form = this.element.querySelector("#item-variant-vendor-modal form")
    if (form) {
      form.action = form.dataset?.createUrl || "/items/setup_modals/variant_vendors"
      form.querySelector("[name='_method']")?.remove()
    }
    if (this.hasTitleTarget) {
      this.titleTarget.textContent = button.dataset.modalTitle || "Add variant vendor"
    }
  }

  prepareVariantVendorEdit(event) {
    const button = event.currentTarget
    this.populateVendorFields(button)
    const form = this.element.querySelector("#item-variant-vendor-modal form")
    if (form && button.dataset.updateUrl) {
      form.action = button.dataset.updateUrl
      this.ensurePatchMethod(form)
    }
    if (this.hasTitleTarget) {
      this.titleTarget.textContent = button.dataset.modalTitle || "Edit variant vendor"
    }
  }

  prepareClassificationEdit(event) {
    const button = event.currentTarget
    if (this.hasVariantIdFieldTarget) {
      this.variantIdFieldTarget.value = button.dataset.variantId || ""
    }
    if (this.hasSubDepartmentFieldTarget && button.dataset.subDepartmentId) {
      this.subDepartmentFieldTarget.value = button.dataset.subDepartmentId
      this.subDepartmentFieldTarget.dispatchEvent(new Event("change", { bubbles: true }))
    }
    const form = this.element.querySelector("#item-classification-modal form")
    if (form && button.dataset.variantId) {
      form.action = `/items/setup_modals/variants/${button.dataset.variantId}/classification`
    }
    if (this.hasTitleTarget) {
      this.titleTarget.textContent = `Classification — ${button.dataset.variantSku || "SKU"}`
    }
  }

  populateVendorFields(button) {
    if (this.hasVendorItemNumberFieldTarget) {
      this.vendorItemNumberFieldTargets.forEach((field) => {
        field.value = button.dataset.vendorItemNumber || ""
      })
    }
    if (this.hasSupplierDiscountFieldTarget) {
      this.supplierDiscountFieldTargets.forEach((field) => {
        field.value = button.dataset.supplierDiscountBps || ""
      })
    }
    if (this.hasReturnabilityFieldTarget) {
      this.returnabilityFieldTargets.forEach((field) => {
        field.value = button.dataset.returnabilityStatus || ""
      })
    }
    if (this.hasPreferredFieldTarget) {
      this.preferredFieldTargets.forEach((field) => {
        field.checked = button.dataset.preferred === "true"
      })
    }
  }

  resetIdentifierForm() {
    if (this.hasIdentifierTypeFieldTarget) {
      this.identifierTypeFieldTarget.disabled = false
      this.identifierTypeFieldTarget.value = "isbn13"
    }
    if (this.hasPrimaryFieldTarget) this.primaryFieldTarget.checked = false
    const form = this.element.querySelector("#item-identifier-modal form")
    if (form) {
      form.action = form.dataset.createUrl
      form.querySelector("[name='_method']")?.remove()
    }
  }

  ensurePatchMethod(form) {
    form.querySelector("[name='_method']")?.remove()
    const method = document.createElement("input")
    method.type = "hidden"
    method.name = "_method"
    method.value = "patch"
    form.appendChild(method)
  }
}
