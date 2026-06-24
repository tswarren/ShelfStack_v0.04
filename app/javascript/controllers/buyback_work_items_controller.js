import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["row", "filter"]

  filter(event) {
    const filter = event.currentTarget.dataset.filter
    this.filterTargets.forEach((chip) => {
      chip.setAttribute("aria-pressed", chip.dataset.filter === filter ? "true" : "false")
      chip.classList.toggle("ss-buyback-filter-chip--active", chip.dataset.filter === filter)
    })

    this.rowTargets.forEach((row) => {
      const state = row.dataset.workflowState
      const visible = filter === "all" || state === filter
      row.hidden = !visible
    })
  }

  openNext(event) {
    event.preventDefault()
    const href = event.currentTarget.getAttribute("href")
    if (!href) return
    const target = document.querySelector(href)
    if (target) {
      target.scrollIntoView({ behavior: "smooth", block: "center" })
      target.classList.add("ss-buyback-row--highlight")
      window.setTimeout(() => target.classList.remove("ss-buyback-row--highlight"), 2000)
    }
  }

  connect() {
    const active = this.filterTargets.find((chip) => chip.dataset.filter === "all")
    if (active) {
      active.classList.add("ss-buyback-filter-chip--active")
    }
  }
}
