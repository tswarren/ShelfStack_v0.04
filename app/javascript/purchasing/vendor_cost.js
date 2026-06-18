// Mirrors Purchasing::VendorCostCalculator

export function parseIntField(value) {
  if (value === "" || value == null) return null
  const parsed = parseInt(value, 10)
  return Number.isNaN(parsed) ? null : parsed
}

export function unitCostCents(listCents, discountBps) {
  if (listCents == null) return null

  const discount = discountBps ?? 0
  return Math.round((listCents * (10_000 - discount)) / 10_000)
}

export function discountBpsFromCost(listCents, costCents) {
  if (listCents == null || listCents <= 0) return null
  if (costCents == null) return null

  const bps = Math.round((1 - costCents / listCents) * 10_000)
  return Math.min(10_000, Math.max(0, bps))
}
