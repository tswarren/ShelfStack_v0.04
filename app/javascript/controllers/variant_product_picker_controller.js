import { Controller } from "@hotwired/stimulus"

// Reloads the new-variant form when staff pick a product so the correct
// standard/conditional/variable/matrix fields render for that product.
export default class extends Controller {
  static values = {
    url: String
  }

  visit(event) {
    const productId = event.target.value
    if (!productId) return

    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("product_id", productId)

    const returnTo = new URL(window.location.href).searchParams.get("return_to")
    if (returnTo) url.searchParams.set("return_to", returnTo)

    const conditionId = new URL(window.location.href).searchParams.get("condition_id")
    if (conditionId) url.searchParams.set("condition_id", conditionId)

    window.location.assign(url.toString())
  }
}
