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
        if (this.isInteractiveControl(event.target)) return

        event.preventDefault()
        if (this.requiredSlipPending()) {
          this.requiredSlipAction()?.click()
        } else {
          this.newSaleActionTarget?.click()
        }
        break
      case "p":
      case "P":
        if (!this.hasReceiptActionTarget) return

        event.preventDefault()
        this.receiptActionTarget.click()
        break
      case "v":
      case "V": {
        const slip = this.preferredSlipAction()
        if (!slip) return

        event.preventDefault()
        slip.click()
        break
      }
      case "Escape":
        event.preventDefault()
        window.location.assign("/pos")
        break
      default:
        break
    }
  }

  preferredSlipAction() {
    return this.slipActionTargets.find((action) => action.dataset.required === "true") ||
      this.slipActionTargets[0]
  }

  requiredSlipPending() {
    return this.requiredSlipUrlValue.length > 0
  }

  requiredSlipAction() {
    return this.preferredSlipAction()
  }

  isInteractiveControl(target) {
    return target instanceof HTMLElement &&
      target.closest("button, a, input, textarea, select, [role='button']")
  }

  isTypingInField(target) {
    if (!(target instanceof HTMLElement)) return false

    const tag = target.tagName
    return tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT" || target.isContentEditable
  }
}
