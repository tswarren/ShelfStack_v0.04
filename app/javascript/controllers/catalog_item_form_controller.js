import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["typeSelect", "fieldGroup", "creatorsSource", "creatorsPreview", "subjectsSource", "subjectsPreview"]

  connect() {
    this.refresh()
    this.bindMetadataPreviews()
  }

  refresh() {
    const selected = this.hasTypeSelectTarget ? this.typeSelectTarget.value : "book"

    this.fieldGroupTargets.forEach((group) => {
      const types = group.dataset.catalogFields.split(" ")
      group.style.display = types.includes(selected) ? "" : "none"
    })
  }

  bindMetadataPreviews() {
    if (this.hasCreatorsSourceTarget && this.hasCreatorsPreviewTarget) {
      this.bindPreview(this.creatorsSourceTarget, this.creatorsPreviewTarget, this.parseCreatorPreview.bind(this))
    }

    if (this.hasSubjectsSourceTarget && this.hasSubjectsPreviewTarget) {
      this.bindPreview(this.subjectsSourceTarget, this.subjectsPreviewTarget, this.parseSubjectPreview.bind(this))
    }
  }

  bindPreview(source, preview, parser) {
    const update = () => {
      preview.textContent = parser(source.value)
    }

    source.addEventListener("input", update)
    source.addEventListener("change", update)
  }

  splitOutsideBrackets(input) {
    const parts = []
    let current = ""
    let depth = 0

    for (const char of input) {
      if (char === "[") {
        depth += 1
        current += char
      } else if (char === "]") {
        if (depth > 0) depth -= 1
        current += char
      } else if (char === ";" && depth === 0) {
        parts.push(current)
        current = ""
      } else {
        current += char
      }
    }

    if (current.length) parts.push(current)

    return parts
  }

  parseCreatorPreview(value) {
    return this.splitOutsideBrackets(value)
      .map((entry) => entry.trim().replace(/\[[^\]]+\]\s*$/, "").trim())
      .filter(Boolean)
      .join("; ") || "—"
  }

  parseSubjectPreview(value) {
    return this.splitOutsideBrackets(value)
      .map((entry) => entry.trim().replace(/\[[A-Za-z0-9_]+(?:\/[^\]]+)?\]\s*$/, "").trim())
      .filter(Boolean)
      .join("; ") || "—"
  }
}
