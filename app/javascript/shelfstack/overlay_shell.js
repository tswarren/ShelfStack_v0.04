import { focusFirstMeaningful, handleFocusTrap } from "shelfstack/focus_trap"
import { restoreFocus } from "shelfstack/focus_restore"
import { acquireOverlayLock, releaseOverlayLock } from "shelfstack/overlay_lock"

const overlayStack = []

export function isFormDirty(form) {
  if (!form) return false
  if (form.dataset.ssDirty === "true") return true

  const fields = form.querySelectorAll("input, textarea, select")
  return Array.from(fields).some((field) => {
    if (field.type === "hidden" || field.disabled) return false
    if (field.type === "submit" || field.type === "button") return false
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

export function canCloseSafely(root, controller) {
  const dirtyGuard = controller.dirtyGuardValue
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

function pushOverlayStack(controller) {
  removeFromOverlayStack(controller)
  overlayStack.push(controller)
}

function removeFromOverlayStack(controller) {
  const index = overlayStack.indexOf(controller)
  if (index === -1) return
  overlayStack.splice(index, 1)
}

function isTopmostOverlay(controller) {
  return overlayStack.length > 0 && overlayStack[overlayStack.length - 1] === controller
}

export function overlayStackDepthForTests() {
  return overlayStack.length
}

export function resetOverlayStackForTests() {
  overlayStack.length = 0
}

export function showOverlay(controller) {
  const shell = controller._overlayShell
  if (!shell || controller.element.hidden === false) return

  controller.element.hidden = false
  acquireOverlayLock(shell.lockKind)
  pushOverlayStack(controller)

  const panel = controller.element.querySelector(shell.panelSelector)
  shell.keydownHandler = (event) => {
    if (!isTopmostOverlay(controller)) return

    if (event.key === "Escape") {
      if (controller.closeOnEscapeValue) {
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

function finalizeOverlayClose(controller, { shouldRestoreFocus = true } = {}) {
  const shell = controller._overlayShell
  if (!shell) return false

  const opener = shell.opener
  shell.opener = null

  removeFromOverlayStack(controller)

  controller.element.hidden = true
  releaseOverlayLock(shell.lockKind)
  teardownOverlayListeners(shell)

  if (shouldRestoreFocus && opener) restoreFocus(opener)

  controller.element.dispatchEvent(new CustomEvent(shell.closedEvent, { bubbles: true }))
  return true
}

function teardownOverlayListeners(shell) {
  if (!shell.keydownHandler) return

  document.removeEventListener("keydown", shell.keydownHandler)
  shell.keydownHandler = null
}

export function closeOverlay(controller, { force = false, shouldRestoreFocus = true } = {}) {
  const shell = controller._overlayShell
  if (!shell || controller.element.hidden === true) return false
  if (!force && !canCloseSafely(controller.element, controller)) return false

  return finalizeOverlayClose(controller, { shouldRestoreFocus })
}

export function cleanupOverlay(controller, { shouldRestoreFocus = false } = {}) {
  const shell = controller._overlayShell
  if (!shell) return

  removeFromOverlayStack(controller)

  if (controller.element.hidden !== true) {
    controller.element.hidden = true
    releaseOverlayLock(shell.lockKind)
  }

  teardownOverlayListeners(shell)

  const opener = shell.opener
  shell.opener = null
  if (shouldRestoreFocus && opener) restoreFocus(opener)
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
    if (!isTopmostOverlay(controller)) return
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
