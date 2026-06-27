export function restoreFocus(opener) {
  if (!opener || typeof opener.focus !== "function") return false
  if (!document.contains(opener)) return false

  opener.focus()
  return true
}

export function resolveFocusRestoreId(id) {
  if (!id) return null
  return document.getElementById(id)
}
