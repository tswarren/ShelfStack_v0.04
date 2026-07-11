import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "primarySearch",
    "primaryHidden",
    "primaryDisplay",
    "primaryClear",
    "additionalContainer",
    "additionalDisplay",
    "additionalTemplate",
    "linkedPreview",
    "advancedField"
  ]

  static values = {
    searchUrl: String,
    primaryId: Number,
    primaryLabel: String,
    additionalSelections: Array
  }

  connect() {
    this.debounceTimer = null
    this.activeResultIndex = -1
    this.currentResults = []
    this.renderPrimarySelection()
    this.renderAdditionalSelections()
    this.updateLinkedPreview()
  }

  searchPrimary(event) {
    this.runSearch(event.target.value, (results) => this.showPrimaryResults(results, event.target))
  }

  searchAdditional(event) {
    const input = event.target
    this.runSearch(input.value, (results) => this.showAdditionalResults(results, input))
  }

  runSearch(query, callback) {
    clearTimeout(this.debounceTimer)
    const trimmed = query.trim()
    if (trimmed.length < 2) {
      callback([])
      return
    }

    this.debounceTimer = setTimeout(async () => {
      const url = new URL(this.searchUrlValue, window.location.origin)
      url.searchParams.set("q", trimmed)
      const response = await fetch(url, { headers: { Accept: "application/json" } })
      if (!response.ok) return
      const payload = await response.json()
      callback(payload.results || [])
    }, 250)
  }

  showPrimaryResults(results, input) {
    this.removeResultsList()
    this.currentResults = results
    this.activeResultIndex = -1
    if (results.length === 0) return

    const list = this.buildResultsList(results, (result) => {
      this.selectPrimary(result)
      input.value = ""
      this.removeResultsList()
    })
    input.parentElement.appendChild(list)
  }

  showAdditionalResults(results, input) {
    this.removeResultsList()
    if (results.length === 0) return

    const list = this.buildResultsList(results, (result) => {
      this.addAdditional(result)
      input.value = ""
      this.removeResultsList()
    })
    input.parentElement.appendChild(list)
  }

  buildResultsList(results, onSelect) {
    const list = document.createElement("ul")
    list.className = "ss-autocomplete-results"
    list.setAttribute("role", "listbox")

    results.forEach((result) => {
      const item = document.createElement("li")
      item.className = "ss-autocomplete-result"
      item.textContent = `${result.breadcrumb_label} (${result.node_key})`
      item.addEventListener("mousedown", (event) => {
        event.preventDefault()
        onSelect(result)
      })
      list.appendChild(item)
    })

    return list
  }

  removeResultsList() {
    this.element.querySelectorAll(".ss-autocomplete-results").forEach((element) => element.remove())
  }

  selectPrimary(result) {
    this.primaryIdValue = result.id
    this.primaryLabelValue = `${result.breadcrumb_label} (${result.node_key})`
    this.primaryHiddenTarget.value = result.id
    this.renderPrimarySelection()
    this.updateLinkedPreview()
  }

  clearPrimary() {
    this.primaryIdValue = 0
    this.primaryLabelValue = ""
    this.primaryHiddenTarget.value = ""
    this.renderPrimarySelection()
    this.updateLinkedPreview()
  }

  addAdditional(result) {
    const selections = this.additionalSelectionsValue
    if (selections.some((entry) => entry.id === result.id)) return
    if (this.primaryIdValue === result.id) return

    selections.push({
      id: result.id,
      label: `${result.breadcrumb_label} (${result.node_key})`
    })
    this.additionalSelectionsValue = selections
    this.renderAdditionalSelections()
    this.updateLinkedPreview()
  }

  removeAdditional(event) {
    const id = Number(event.currentTarget.dataset.id)
    this.additionalSelectionsValue = this.additionalSelectionsValue.filter((entry) => entry.id !== id)
    this.renderAdditionalSelections()
    this.updateLinkedPreview()
  }

  renderPrimarySelection() {
    if (!this.hasPrimaryDisplayTarget) return

    if (this.primaryIdValue) {
      this.primaryDisplayTarget.textContent = this.primaryLabelValue
      this.primaryClearTarget.hidden = false
    } else {
      this.primaryDisplayTarget.textContent = "None selected"
      this.primaryClearTarget.hidden = true
    }
  }

  renderAdditionalSelections() {
    if (this.hasAdditionalContainerTarget) {
      this.additionalContainerTarget.innerHTML = ""
      this.additionalSelectionsValue.forEach((entry) => {
        const hidden = document.createElement("input")
        hidden.type = "hidden"
        hidden.name = "bisac_category_node_ids[]"
        hidden.value = entry.id
        hidden.dataset.productCanonicalInput = "true"
        this.additionalContainerTarget.appendChild(hidden)
      })
    }

    if (!this.hasAdditionalDisplayTarget) return

    this.additionalDisplayTarget.innerHTML = ""
    this.additionalSelectionsValue.forEach((entry) => {
      const row = document.createElement("div")
      row.className = "ss-bisac-selection-row"

      const label = document.createElement("span")
      label.textContent = entry.label
      row.appendChild(label)

      const button = document.createElement("button")
      button.type = "button"
      button.className = "ss-btn ss-btn-secondary ss-btn-small"
      button.textContent = "Remove"
      button.dataset.id = entry.id
      button.dataset.action = "bisac-subjects#removeAdditional"
      row.appendChild(button)

      this.additionalDisplayTarget.appendChild(row)
    })
  }

  updateLinkedPreview() {
    if (!this.hasLinkedPreviewTarget) return

    const labels = []
    if (this.primaryLabelValue) labels.push(`${this.primaryLabelValue} (primary)`)
    this.additionalSelectionsValue.forEach((entry) => labels.push(entry.label))
    this.linkedPreviewTarget.textContent = labels.length ? labels.join("; ") : "—"
  }

  primaryIdValueChanged() {
    this.renderPrimarySelection()
    this.updateLinkedPreview()
  }

  additionalSelectionsValueChanged() {
    this.renderAdditionalSelections()
    this.updateLinkedPreview()
  }
}
