import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { printUrl: String }

  print(event) {
    event.preventDefault()
    window.print()

    if (!this.hasPrintUrlValue) {
      return
    }

    fetch(this.printUrlValue, {
      method: "PATCH",
      headers: {
        Accept: "text/vnd.turbo-stream.html, text/html, application/xhtml+xml",
        "X-CSRF-Token": this.#csrfToken
      },
      credentials: "same-origin"
    }).catch(() => {})
  }

  get #csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content
  }
}
