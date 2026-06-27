const lockCounts = {
  modal: 0,
  drawer: 0
}

const BODY_CLASSES = {
  modal: "ss-modal-open",
  drawer: "ss-drawer-open"
}

function syncBodyClasses() {
  document.body.classList.toggle(BODY_CLASSES.modal, lockCounts.modal > 0)
  document.body.classList.toggle(BODY_CLASSES.drawer, lockCounts.drawer > 0)
}

export function acquireOverlayLock(kind) {
  if (!Object.prototype.hasOwnProperty.call(lockCounts, kind)) return

  lockCounts[kind] += 1
  syncBodyClasses()
}

export function releaseOverlayLock(kind) {
  if (!Object.prototype.hasOwnProperty.call(lockCounts, kind)) return

  lockCounts[kind] = Math.max(0, lockCounts[kind] - 1)
  syncBodyClasses()
}

export function overlayLockCount(kind) {
  return lockCounts[kind] || 0
}

export function resetOverlayLocksForTests() {
  lockCounts.modal = 0
  lockCounts.drawer = 0
  syncBodyClasses()
}
