import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["newSaleAction", "receiptAction", "slipAction"]
  static values = {
    requiredSlipUrl: String
  }

  connect() {
    this.boundKeydown = this.keydown.bind(this)
    document.addEventListener("keydown", this.boundKeydown)
    this.focusPrimaryAction()
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundKeydown)
  }

  focusPrimaryAction() {
    if (this.requiredSlipPending()) {
      this.requiredSlipAction()?.focus()
      return
    }

    this.newSaleActionTarget?.focus()
  }

  keydown(event) {
    if (this.isTypingInField(event.target)) return

    switch (event.key) {
      case "Enter":
        event.preventDefault()
        if (this.requiredSlipPending()) {
          this.requiredSlipAction()?.click()
        } else {
          this.newSaleActionTarget?.click()
        }
        break
      case "p":
      case "P":
        event.preventDefault()
        this.receiptActionTarget?.click()
        break
      case "v":
      case "V":
        event.preventDefault()
        this.slipActionTargets.find((action) => action.dataset.required === "true")?.click()
        break
      case "Escape":
        event.preventDefault()
        window.location.assign("/pos")
        break
      default:
        break
    }
  }

  requiredSlipPending() {
    return this.requiredSlipUrlValue.length > 0
  }

  requiredSlipAction() {
    return this.slipActionTargets.find((action) => action.dataset.required === "true")
  }

  isTypingInField(target) {
    if (!(target instanceof HTMLElement)) return false

    const tag = target.tagName
    return tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT" || target.isContentEditable
  }
}
