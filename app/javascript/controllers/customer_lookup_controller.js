import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "lookupInput",
    "customerId",
    "preview",
    "message",
    "choices",
    "walkInFields"
  ]

  static values = {
    url: String,
    initialCustomerId: String,
    initialLabel: String,
    initialEmail: String,
    initialPhone: String
  }

  connect() {
    if (this.hasInitialCustomerIdValue && this.initialCustomerIdValue) {
      this.customerIdTarget.value = this.initialCustomerIdValue
      this.lookupInputTarget.value = this.initialLabelValue || ""
      this.renderSelected({
        display_name: this.initialLabelValue,
        email: this.initialEmailValue,
        phone: this.initialPhoneValue
      })
      this.toggleWalkInFields(false)
    }
  }

  lookupExact(event) {
    if (event.type === "keydown" && event.key !== "Enter") return
    if (event.type === "keydown") event.preventDefault()

    this.clearChoices()
    const query = this.lookupInputTarget.value.trim()
    if (!query) {
      this.clearSelection("Enter a customer name, email, or phone.")
      return
    }

    this.fetchLookup({ q: query, mode: "exact" })
  }

  search() {
    const query = this.lookupInputTarget.value.trim()
    if (query.length < 2) {
      this.clearChoices()
      if (!this.customerIdTarget.value) {
        this.previewTarget.textContent = ""
      }
      return
    }

    if (this.customerIdTarget.value && query !== this.selectedLabel) {
      this.customerIdTarget.value = ""
      this.toggleWalkInFields(true)
    }

    this.fetchLookup({ q: query, mode: "search" })
  }

  fetchLookup(params) {
    const lookupUrl = new URL(this.urlValue, window.location.origin)
    Object.entries(params).forEach(([key, value]) => lookupUrl.searchParams.set(key, value))

    fetch(lookupUrl)
      .then((response) => response.json())
      .then((data) => this.renderResult(data))
      .catch(() => {
        this.messageTarget.textContent = "Unable to look up customer right now."
        this.messageTarget.className = "ss-hint ss-hint--warning"
      })
  }

  renderResult(data) {
    this.messageTarget.textContent = data.message || ""
    this.messageTarget.className = data.message ? "ss-hint ss-hint--warning" : "ss-hint"

    if (data.status === "found") {
      this.selectCustomer(data.customers[0])
      return
    }

    if (data.status === "ambiguous" || data.status === "search") {
      this.renderChoices(data.customers)
      return
    }

    this.clearSelection(data.message)
  }

  renderChoices(customers) {
    this.choicesTarget.innerHTML = ""
    customers.forEach((customer) => {
      const card = document.createElement("button")
      card.type = "button"
      card.className = "ss-pos-choice-card"
      card.innerHTML = this.choiceCardHtml(customer)
      card.addEventListener("click", () => this.selectCustomer(customer))
      this.choicesTarget.appendChild(card)
    })
  }

  choiceCardHtml(customer) {
    const email = customer.email || "—"
    const phone = customer.phone || "—"
    return `
      <strong class="ss-pos-choice-card__sku">${customer.display_name}</strong>
      <span class="ss-pos-choice-card__meta">${email} · ${phone}</span>
    `
  }

  selectCustomer(customer) {
    this.customerIdTarget.value = customer.id
    this.lookupInputTarget.value = customer.display_name
    this.selectedLabel = customer.display_name
    this.renderSelected(customer)
    this.clearChoices()
    this.messageTarget.textContent = ""
    this.messageTarget.className = "ss-hint"
    this.toggleWalkInFields(false)
  }

  clearCustomer(event) {
    event.preventDefault()
    this.clearSelection("")
    this.lookupInputTarget.value = ""
    this.lookupInputTarget.focus()
  }

  renderSelected(customer) {
    const email = customer.email || "—"
    const phone = customer.phone || "—"
    this.previewTarget.textContent = `${customer.display_name} · ${email} · ${phone}`
  }

  clearSelection(message) {
    this.customerIdTarget.value = ""
    this.selectedLabel = ""
    this.previewTarget.textContent = ""
    this.clearChoices()
    this.toggleWalkInFields(true)
    if (message) {
      this.messageTarget.textContent = message
      this.messageTarget.className = "ss-hint ss-hint--warning"
    }
  }

  clearChoices() {
    this.choicesTarget.innerHTML = ""
  }

  toggleWalkInFields(show) {
    if (!this.hasWalkInFieldsTarget) return
    this.walkInFieldsTarget.hidden = !show
  }
}
