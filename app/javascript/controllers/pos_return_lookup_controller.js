import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results", "message"]
  static values = {
    url: String,
    addUrl: String,
    redirectOnSuccess: { type: Boolean, default: false }
  }

  lookup(event) {
    if (event.type === "keydown" && event.key !== "Enter") return
    if (event.type === "keydown") event.preventDefault()

    const transactionNumber = this.inputTarget.value.trim()
    if (!transactionNumber) {
      this.showMessage("Enter a receipt number.")
      return
    }

    const lookupUrl = new URL(this.urlValue, window.location.origin)
    lookupUrl.searchParams.set("transaction_number", transactionNumber)

    fetch(lookupUrl)
      .then((response) => response.json())
      .then((data) => this.renderResult(data))
      .catch(() => this.showMessage("Unable to look up receipt."))
  }

  renderResult(data) {
    if (data.status !== "found") {
      this.resultsTarget.innerHTML = ""
      this.showMessage(data.message || "Receipt not found.")
      return
    }

    this.showMessage(data.message || "")
    this.resultsTarget.innerHTML = ""

    const heading = document.createElement("p")
    heading.textContent = `Receipt ${data.transaction.transaction_number} — ${data.transaction.completed_at}`
    this.resultsTarget.appendChild(heading)

    data.lines.forEach((line) => {
      if (!line.returnable || line.remaining_quantity <= 0) return

      const row = document.createElement("div")
      row.className = "ss-pos-return-line"

      const form = document.createElement("form")
      form.method = "post"
      form.action = this.addUrlValue
      form.setAttribute("data-turbo-stream", "true")

      const token = document.querySelector("meta[name='csrf-token']")?.getAttribute("content")
      if (!token) {
        this.showMessage("Session expired. Refresh the page and try again.")
        return
      }

      form.innerHTML = `
        <input type="hidden" name="authenticity_token" value="${token}">
        <input type="hidden" name="source_transaction_line_id" value="${line.id}">
        <span>${line.sku} — ${line.name} (sold ${line.sold_quantity}, remaining ${line.remaining_quantity})</span>
        <label>Qty <input type="number" name="quantity" value="1" min="1" max="${line.remaining_quantity}"></label>
        <select name="return_disposition">
          <option value="return_to_stock">Return to stock</option>
          <option value="damaged">Damaged</option>
          <option value="defective">Defective</option>
          <option value="return_to_vendor_candidate">Return to vendor candidate</option>
          <option value="other">Other</option>
        </select>
        <button type="submit" class="ss-btn ss-btn-secondary">Add return line</button>
      `
      form.addEventListener("submit", (event) => this.submitReturnLine(event))
      row.appendChild(form)
      this.resultsTarget.appendChild(row)
    })
  }

  submitReturnLine(event) {
    event.preventDefault()
    const form = event.currentTarget
    const body = new FormData(form)

    fetch(form.action, {
      method: "POST",
      headers: {
        "X-CSRF-Token": body.get("authenticity_token"),
        Accept: this.redirectOnSuccessValue ? "text/html" : "text/vnd.turbo-stream.html"
      },
      body
    })
      .then((response) => {
        if (this.redirectOnSuccessValue && response.redirected) {
          window.location.href = response.url
          return null
        }
        if (!response.ok) throw new Error(`Add return line failed (${response.status})`)
        return response.text()
      })
      .then((html) => {
        if (!html) return

        window.Turbo.renderStreamMessage(html)
        document.querySelector(".ss-pos-scan-input")?.focus()
      })
      .catch(() => this.showMessage("Unable to add return line."))
  }

  showMessage(message) {
    this.messageTarget.textContent = message
    this.messageTarget.hidden = !message
  }
}
