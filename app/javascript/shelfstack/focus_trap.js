const FOCUSABLE_SELECTOR = [
  "a[href]",
  "button:not([disabled])",
  "textarea:not([disabled])",
  "input:not([disabled])",
  "select:not([disabled])",
  "[tabindex]:not([tabindex='-1'])"
].join(", ")

const CLOSE_BUTTON_SELECTOR = ".ss-modal-close, .ss-drawer-close"

export function focusableElements(container) {
  return Array.from(container.querySelectorAll(FOCUSABLE_SELECTOR)).filter((element) => {
    return element.offsetParent !== null && !element.hidden && element.getAttribute("aria-hidden") !== "true"
  })
}

export function focusFirstMeaningful(container) {
  const elements = focusableElements(container)
  const preferred = elements.find((element) => !element.matches(CLOSE_BUTTON_SELECTOR))
  const target = preferred || elements[0]
  target?.focus()
  return target
}

export function handleFocusTrap(container, event) {
  if (event.key !== "Tab") return

  const elements = focusableElements(container)
  if (elements.length === 0) return

  const first = elements[0]
  const last = elements[elements.length - 1]
  const active = document.activeElement

  if (event.shiftKey && active === first) {
    event.preventDefault()
    last.focus()
  } else if (!event.shiftKey && active === last) {
    event.preventDefault()
    first.focus()
  }
}
