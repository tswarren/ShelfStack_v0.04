import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["receiptSection", "noReceiptSection", "receiptTab", "noReceiptTab"]

  showReceipt(event) {
    event?.preventDefault()
    this.receiptSectionTarget.hidden = false
    this.noReceiptSectionTarget.hidden = true
    this.setActiveTab(this.receiptTabTarget)
    this.receiptSectionTarget.querySelector("[data-pos-return-lookup-target='input']")?.focus()
  }

  showNoReceipt(event) {
    event?.preventDefault()
    this.receiptSectionTarget.hidden = true
    this.noReceiptSectionTarget.hidden = false
    this.setActiveTab(this.noReceiptTabTarget)
    this.noReceiptSectionTarget.querySelector("[data-pos-line-entry-target='query']")?.focus()
  }

  setActiveTab(activeTab) {
    ;[this.receiptTabTarget, this.noReceiptTabTarget].forEach((tab) => {
      const active = tab === activeTab
      tab.classList.toggle("ss-pos-entry-switch__btn--active", active)
      tab.setAttribute("aria-selected", active ? "true" : "false")
    })
  }
}
