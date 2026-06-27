import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  openModalBody(event) {
    const button = event.currentTarget
    const modalId = event.params?.targetId || button.dataset.modalTargetIdParam
    const bodyUrl = button.dataset.modalBodyUrl
    const modalTitle = button.dataset.modalTitle

    if (!modalId || !bodyUrl) return

    const modal = document.getElementById(modalId)
    if (!modal) return

    const frame = modal.querySelector("turbo-frame")
    if (frame) {
      frame.src = bodyUrl
    }

    if (modalTitle) {
      const title = modal.querySelector(".ss-modal-title")
      if (title) title.textContent = modalTitle
    }
  }

  prepareIdentifierCreate(_event) {
    this.resetIdentifierForm()
    this.setIdentifierModalTitle("Add identifier")
  }

  prepareIdentifierEdit(event) {
    const button = event.currentTarget
    const modal = document.getElementById("item-identifier-modal")
    if (!modal) return

    const valueField = modal.querySelector("[data-item-setup-modal-target='identifierValueField']")
    const typeField = modal.querySelector("[data-item-setup-modal-target='identifierTypeField']")
    const primaryField = modal.querySelector("[data-item-setup-modal-target='primaryField']")
    const form = modal.querySelector("form")

    if (valueField) valueField.value = button.dataset.identifierValue || ""
    if (typeField) {
      typeField.value = button.dataset.identifierType || "isbn13"
      typeField.disabled = true
    }
    if (primaryField) primaryField.checked = button.dataset.primary === "true"

    if (form) {
      form.action = button.dataset.updateUrl || form.dataset.createUrl
      form.querySelector("[name='_method']")?.remove()
      if (button.dataset.updateUrl) {
        const method = document.createElement("input")
        method.type = "hidden"
        method.name = "_method"
        method.value = "patch"
        form.appendChild(method)
      }
    }

    this.setIdentifierModalTitle("Edit identifier")
  }

  resetIdentifierForm() {
    const modal = document.getElementById("item-identifier-modal")
    if (!modal) return

    const typeField = modal.querySelector("[data-item-setup-modal-target='identifierTypeField']")
    const primaryField = modal.querySelector("[data-item-setup-modal-target='primaryField']")
    const form = modal.querySelector("form")

    if (typeField) {
      typeField.disabled = false
      typeField.value = "isbn13"
    }
    if (primaryField) primaryField.checked = false
    if (form) {
      form.action = form.dataset.createUrl
      form.querySelector("[name='_method']")?.remove()
    }
  }

  setIdentifierModalTitle(text) {
    const modal = document.getElementById("item-identifier-modal")
    const title = modal?.querySelector(".ss-modal-title")
    if (title) title.textContent = text
  }
}
