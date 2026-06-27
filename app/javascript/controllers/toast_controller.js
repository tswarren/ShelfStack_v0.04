import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    autoDismissMs: { type: Number, default: 5000 },
    dismissible: { type: Boolean, default: true }
  }

  connect() {
    this.resumeTimer = this.resumeTimer.bind(this)
    this.pauseTimer = this.pauseTimer.bind(this)

    if (this.autoDismissMsValue > 0) {
      this.scheduleDismiss()
      this.element.addEventListener("mouseenter", this.pauseTimer)
      this.element.addEventListener("mouseleave", this.resumeTimer)
      this.element.addEventListener("focusin", this.pauseTimer)
      this.element.addEventListener("focusout", this.resumeTimer)
    }
  }

  disconnect() {
    this.clearDismissTimer()
    this.element.removeEventListener("mouseenter", this.pauseTimer)
    this.element.removeEventListener("mouseleave", this.resumeTimer)
    this.element.removeEventListener("focusin", this.pauseTimer)
    this.element.removeEventListener("focusout", this.resumeTimer)
  }

  dismiss(event) {
    event?.preventDefault()
    this.removeToast()
  }

  scheduleDismiss() {
    this.clearDismissTimer()
    this.dismissTimer = window.setTimeout(() => this.removeToast(), this.autoDismissMsValue)
  }

  pauseTimer() {
    this.clearDismissTimer()
  }

  resumeTimer() {
    if (this.autoDismissMsValue > 0) this.scheduleDismiss()
  }

  clearDismissTimer() {
    if (this.dismissTimer) {
      window.clearTimeout(this.dismissTimer)
      this.dismissTimer = null
    }
  }

  removeToast() {
    this.clearDismissTimer()
    this.element.remove()
  }
}
