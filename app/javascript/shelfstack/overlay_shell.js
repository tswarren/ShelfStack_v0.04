import { focusFirstMeaningful, handleFocusTrap } from "shelfstack/focus_trap"
import { restoreFocus } from "shelfstack/focus_restore"
import { acquireOverlayLock, releaseOverlayLock } from "shelfstack/overlay_lock"

export function isFormDirty(form) {
  if (!form) return false
  if (form.dataset.ssDirty === "true") return true

  const fields = form.querySelectorAll("input, textarea, select")
  return Array.from(fields).some((field) => {
    if (field.type === "hidden" || field.disabled) return false
    if (field.type === "checkbox" || field.type === "radio") {
      return field.checked !== field.defaultChecked
    }
    return field.value !== field.defaultValue
  })
}

export function formHasValidationErrors(form) {
  if (!form) return false
  return form.querySelector("[aria-invalid='true'], .field_with_errors, .ss-field-error") !== null
}

export function isFormSubmitting(form) {
  if (!form) return false
  return form.dataset.ssSubmitting === "true"
}

export function canCloseSafely(root, { dirtyGuard }) {
  const form = root.querySelector("form")
  if (!dirtyGuard || !form) return true
  if (isFormSubmitting(form)) return false
  if (isFormDirty(form)) return false
  if (formHasValidationErrors(form)) return false
  return true
}

export function bindOverlayShell(controller, {
  lockKind,
  panelSelector,
  openedEvent,
  closedEvent
}) {
  controller._overlayShell = {
    lockKind,
    panelSelector,
    openedEvent,
    closedEvent,
    opener: null,
    keydownHandler: null,
    backdropHandler: null
  }
}

export function isOverlayShell(controller) {
  return Boolean(controller._overlayShell)
}

export function showOverlay(controller) {
  const shell = controller._overlayShell
  if (!shell || controller.element.hidden === false) return

  controller.element.hidden = false
  acquireOverlayLock(shell.lockKind)

  const panel = controller.element.querySelector(shell.panelSelector)
  shell.keydownHandler = (event) => {
    if (event.key === "Escape") {
      if (controller.closeOnEscapeValue && canCloseSafely(controller.element, controller)) {
        event.preventDefault()
        closeOverlay(controller)
      }
      return
    }
    if (panel) handleFocusTrap(panel, event)
  }
  document.addEventListener("keydown", shell.keydownHandler)

  if (panel) focusFirstMeaningful(panel)

  controller.element.dispatchEvent(new CustomEvent(shell.openedEvent, { bubbles: true }))
}

export function closeOverlay(controller) {
  const shell = controller._overlayShell
  if (!shell || controller.element.hidden === true) return false
  if (!canCloseSafely(controller.element, controller)) return false

  controller.element.hidden = true
  releaseOverlayLock(shell.lockKind)

  if (shell.keydownHandler) {
    document.removeEventListener("keydown", shell.keydownHandler)
    shell.keydownHandler = null
  }

  restoreFocus(shell.opener)
  shell.opener = null

  controller.element.dispatchEvent(new CustomEvent(shell.closedEvent, { bubbles: true }))
  return true
}

export function openOverlayById(application, identifier, id, opener) {
  const element = document.getElementById(id)
  if (!element) return false

  const controller = application.getControllerForElementAndIdentifier(element, identifier)
  if (!controller || !isOverlayShell(controller)) return false

  controller._overlayShell.opener = opener || null
  showOverlay(controller)
  return true
}

export function bindBackdropClose(controller, backdropTarget) {
  const shell = controller._overlayShell
  if (!shell || !backdropTarget) return

  shell.backdropHandler = (event) => {
    if (!controller.closeOnBackdropValue) return
    if (!canCloseSafely(controller.element, controller)) return
    event.preventDefault()
    closeOverlay(controller)
  }
  backdropTarget.addEventListener("click", shell.backdropHandler)
}

export function unbindBackdropClose(controller, backdropTarget) {
  const shell = controller._overlayShell
  if (!shell?.backdropHandler || !backdropTarget) return

  backdropTarget.removeEventListener("click", shell.backdropHandler)
  shell.backdropHandler = null
}
