# ShelfStack Item-Centered Edit Flow Alignment

## Branch Reviewed

Repository: `tswarren/ShelfStack_v0.03`  
Branch: `phase-3-catalog-products-variants`

## Goal

Align catalog item, product, and product variant edit flows with the new item workflow.

The desired UX is:

```text
/items/item?... is the core operational view.
Catalog, product, and variant edits should behave as subflows of the item page.
````

The existing resource routes can remain, but users should generally start from and return to the appropriate `/items/item` tab rather than being sent to separate legacy `/items/products/:id`, `/items/catalog_items/:id`, or `/items/product_variants/:id` pages.

---

# Current State

## Routes

The branch already has the correct basic structure:

```ruby
namespace :items do
  get "item", to: "items#show", as: :item

  resources :catalog_items
  resources :products
  resources :product_variants
end
```

So the item show surface exists, while catalog/product/variant CRUD still exists separately.

## Item show page

`Items::ItemsController#show` already works as the central read surface.

It supports these tabs:

```ruby
VALID_TABS = %w[overview catalog selling display activity].freeze
```

The controller can load an item from either:

```ruby
params[:catalog_item_id]
params[:product_id]
```

and then render tab-specific data:

```ruby
catalog tab -> identifiers
selling tab -> variants
activity tab -> audit events
```

This is the right architectural direction.

---

# Main Issue

The item page is becoming the conceptual hub, but the mutation flows still behave like independent legacy CRUD flows.

Examples:

```text
Edit catalog item -> returns to /items/catalog_items/:id
Edit product -> returns to /items/products/:id
Edit variant -> returns to /items/product_variants/:id
Create variant -> returns to /items/product_variants/:id
```

Instead, when these actions are launched from `/items/item`, they should return to:

```text
/items/item?catalog_item_id=...&tab=catalog
/items/item?product_id=...&tab=selling
/items/item?product_id=...&tab=selling&variant_id=...
```

---

# Desired User Workflows

## Catalog Tab

Route concept:

```text
/items/item?catalog_item_id=:id&tab=catalog
```

### Supported actions

| Action                     | Expected behavior                                    |
| -------------------------- | ---------------------------------------------------- |
| Edit catalog details       | Use dynamic catalog form; return to item catalog tab |
| Inactivate                 | Return to item catalog tab                           |
| Reactivate                 | Return to item catalog tab                           |
| Delete                     | If allowed, return to item index/root                |
| Generate Local ID          | Return to item catalog tab                           |
| Add/Edit/Delete identifier | Return to item catalog tab                           |

### Notes

The catalog form is already dynamic based on catalog item type. That part is good and should be reused.

The identifier actions already partially support this pattern through `return_to=item`. That pattern should be generalized to the rest of catalog item actions.

---

## Selling Tab

Route concept:

```text
/items/item?product_id=:id&tab=selling
```

### Supported actions

| Action                        | Expected behavior                                                                        |
| ----------------------------- | ---------------------------------------------------------------------------------------- |
| Edit product                  | Use product form logic aligned with new item wizard; return to item selling tab          |
| New variant                   | Use variation-type-specific variant form; return to item selling tab                     |
| Edit variant                  | Use same form logic as new item wizard; return to item selling tab and highlight variant |
| Inactivate/reactivate variant | Return to item selling tab and highlight variant                                         |
| Delete variant                | Return to item selling tab                                                               |

---

# Recommended Implementation

## 1. Add item-aware return paths

Do not remove the existing resource routes yet. Instead, add return-path helpers that respect:

```ruby
params[:return_to] == "item"
```

This allows legacy direct CRUD pages to continue working while item-tab flows behave correctly.

---

## CatalogItemsController

### Add helper

```ruby
def catalog_item_return_path(tab: "catalog")
  if params[:return_to] == "item"
    Items::ItemPresenter.from_catalog_item(@catalog_item).tab_path(tab)
  else
    items_catalog_item_path(@catalog_item)
  end
end
```

### Use for

```text
update
inactivate
reactivate
generate_local_identifier
set_primary_identifier
add_identifier
update_identifier
destroy_identifier
```

### Delete behavior

If delete succeeds:

```ruby
redirect_to items_root_path, notice: "Catalog item deleted."
```

or return to the item index/search surface used by the app.

If delete is blocked because products exist:

```ruby
redirect_to catalog_item_return_path, alert: "Catalog item cannot be deleted. Inactivate instead."
```

---

## ProductsController

### Add helper

```ruby
def product_return_path
  if params[:return_to] == "item"
    Items::ItemPresenter.from_product(@product).tab_path("selling")
  else
    items_product_path(@product)
  end
end
```

### Use for

```text
update
destroy failure
inactivate
reactivate
regenerate_name
```

### Create behavior

If a product is created from an item flow, return to:

```ruby
Items::ItemPresenter.from_product(@product).tab_path("selling")
```

---

## ProductVariantsController

### Add helper

```ruby
def variant_return_path
  if params[:return_to] == "item"
    Items::ItemPresenter.from_product(@product_variant.product)
      .tab_path("selling", variant_id: @product_variant.id)
  else
    items_product_variant_path(@product_variant)
  end
end
```

### Use for

```text
create
update
inactivate
reactivate
regenerate_name
```

### Destroy behavior

Capture the product before destroying:

```ruby
product = @product_variant.product
@product_variant.destroy
redirect_to Items::ItemPresenter.from_product(product).tab_path("selling"),
            notice: "Product variant deleted."
```

---

# Update Item Tab Links

## Catalog tab

Current catalog tab actions should pass `return_to=item`.

Example:

```erb
<%= link_to "Edit catalog details",
      edit_items_catalog_item_path(item.catalog_item, return_to: "item"),
      class: "ss-btn" %>
```

Also update:

```erb
new_identifier_items_catalog_item_path(item.catalog_item, return_to: "item")
edit_identifier_items_catalog_item_path(item.catalog_item, identifier_id: identifier.id, return_to: "item")
destroy_identifier_items_catalog_item_path(item.catalog_item, identifier_id: identifier.id, return_to: "item")
```

Add actions for:

```text
Inactivate
Reactivate
Delete
Generate Local ID
```

where appropriate.

---

## Selling tab

Update action links to pass `return_to=item`.

```erb
<%= link_to "Edit product",
      edit_items_product_path(item.product, return_to: "item"),
      class: "ss-btn" %>

<%= link_to "New sellable SKU",
      new_items_product_variant_path(product_id: item.product.id, return_to: "item"),
      class: "ss-btn ss-btn-secondary" %>

<%= link_to "Edit",
      edit_items_product_variant_path(variant, return_to: "item") %>
```

---

# Product Edit Form Alignment

## Current issue

The new item wizard has two distinct selling setup flows:

```text
catalog-linked product
non-catalog product
```

But the regular product edit form is generic and always shows:

```text
catalog item selector
name
name override
SKU
product type
variation type
variant labels
price
display location
cover image
active
```

This makes editing feel different from creating.

## Recommended change

Split product edit rendering based on whether the product has a catalog item.

```erb
<% if @product.catalog_item.present? %>
  <%= render "items/products/catalog_linked_form", ... %>
<% else %>
  <%= render "items/products/non_catalog_form", ... %>
<% end %>
```

## Catalog-linked product edit should

* Show catalog item as read-only context.
* Show generated product name preview.
* Allow name override.
* Allow SKU override, with hint from catalog primary identifier.
* Keep or strongly preserve `variation_type = conditional`.
* Allow product type, list price, default display location, cover image, active flag.
* Return to item selling tab.

## Non-catalog product edit should

* Allow product name.
* Allow SKU.
* Allow product type.
* Allow variation type.
* Dynamically show variant labels based on variation type.
* Allow list price, default display location, cover image, active flag.
* Return to item selling tab.

---

# Variant Form Alignment

## Important note

The repository version of the product variant form is not actually blank. The partial currently renders fields for:

```text
product
name/name override
SKU
SKU preview
condition
attribute 1
attribute 2
selling price
category
inventory behavior
display location
active
```

So if the browser shows a blank edit form, likely causes include:

```text
Stimulus controller issue
CSS hiding fields
Turbo/frame rendering issue
empty collection state
runtime exception
local branch mismatch
server not running the expected branch
```

## Product issue

Even though the form is not blank in the repo, it is still not aligned with the new item wizard.

The new item wizard uses variation-type-specific partials:

```erb
case @product.variation_type
when "conditional"
  render "sellable_sku_conditional"
when "variable"
  render "sellable_sku_variable"
when "matrix"
  render "sellable_sku_matrix"
else
  render "sellable_sku_standard"
end
```

The regular variant form is generic and shows all variant fields.

## Recommended change

Extract the wizard variant partials into shared partials and use them for both new and edit.

Suggested structure:

```text
app/views/items/product_variants/forms/_standard.html.erb
app/views/items/product_variants/forms/_conditional.html.erb
app/views/items/product_variants/forms/_variable.html.erb
app/views/items/product_variants/forms/_matrix.html.erb
```

Then both of these should use the same chooser:

```text
items/add_item/sellable_sku.html.erb
items/product_variants/new.html.erb
items/product_variants/edit.html.erb
```

This prevents the new-item wizard and edit forms from drifting apart.

---

# Route Strategy

Do not remove these yet:

```ruby
resources :catalog_items
resources :products
resources :product_variants
```

They are still useful as technical endpoints, direct admin CRUD routes, and fallback/debug routes.

Instead:

```text
/items/item?...         = primary user-facing hub
/items/products/:id/edit = subflow endpoint
return_to=item          = return to item tab after action
```

Later, after this stabilizes, we can decide whether to introduce more semantic item-action routes.

---

# Suggested Acceptance Criteria

## Item-centered navigation

* [ ] Catalog tab includes primary action to edit catalog details.
* [ ] Catalog tab includes secondary actions for inactivate/reactivate/delete/generate local ID as appropriate.
* [ ] Selling tab includes primary action to edit product.
* [ ] Selling tab includes action to create new variant.
* [ ] Selling tab variant rows include edit action.
* [ ] Item tab action links pass `return_to=item`.

## Catalog item actions

* [ ] Updating a catalog item from item flow returns to item catalog tab.
* [ ] Inactivating/reactivating from item flow returns to item catalog tab.
* [ ] Generating a local identifier from item flow returns to item catalog tab.
* [ ] Identifier create/edit/delete from item flow returns to item catalog tab.
* [ ] Successful delete returns to item index/root/search.
* [ ] Blocked delete returns to item catalog tab with alert.

## Product actions

* [ ] Updating a product from item flow returns to item selling tab.
* [ ] Inactivating/reactivating a product from item flow returns to item selling tab.
* [ ] Regenerating product name from item flow returns to item selling tab.
* [ ] Cancel from product edit returns to item selling tab when launched from item flow.
* [ ] Legacy product show still works when product edit is opened directly.

## Product form behavior

* [ ] Catalog-linked product edit uses catalog-linked form logic.
* [ ] Non-catalog product edit uses non-catalog form logic.
* [ ] Catalog-linked edit does not unnecessarily expose catalog item reassignment as a normal field.
* [ ] Non-catalog edit preserves dynamic product type / variation type behavior.
* [ ] Product edit form behavior matches the new item wizard as closely as practical.

## Variant actions

* [ ] Creating a variant from item flow returns to item selling tab.
* [ ] Editing a variant from item flow returns to item selling tab.
* [ ] Inactivating/reactivating a variant from item flow returns to item selling tab.
* [ ] Deleting a variant from item flow returns to item selling tab.
* [ ] Return URL includes `variant_id` when the variant still exists.
* [ ] Selling tab can highlight the newly created or edited variant.

## Variant form behavior

* [ ] Product variant new/edit uses variation-type-specific form logic.
* [ ] Standard products show standard SKU form.
* [ ] Conditional products show condition-oriented form.
* [ ] Variable products show attribute 1 form.
* [ ] Matrix products show attribute 1 + attribute 2 form.
* [ ] Variant edit form is not blank in browser.
* [ ] Legacy direct variant edit still works.

## Regression checks

* [ ] New item wizard still works.
* [ ] Catalog-linked new item flow still works.
* [ ] Non-catalog new item flow still works.
* [ ] Product creation still works.
* [ ] Variant creation still works.
* [ ] Legacy resource show pages still render.
* [ ] Authorization checks remain unchanged.
* [ ] Audit events still record create/update/inactivate/reactivate/delete actions.

---

# Suggested Implementation Order

## Step 1: Return navigation

Add item-aware return helpers to:

```text
Items::CatalogItemsController
Items::ProductsController
Items::ProductVariantsController
```

Update item tab links to pass:

```ruby
return_to: "item"
```

This should be the first PR because it improves UX without major form restructuring.

---

## Step 2: Product edit form split

Split product edit into:

```text
catalog-linked product edit
non-catalog product edit
```

Use the new item wizard behavior as the reference.

---

## Step 3: Shared variant form chooser

Extract variation-type-specific variant partials from the add item wizard into shared partials.

Use those shared partials from:

```text
add item wizard
product variant new
product variant edit
```

---

## Step 4: Clean up item tab actions

Add missing secondary actions on item tabs:

```text
Inactivate
Reactivate
Delete
Generate Local ID
Regenerate name
```

Only show actions that are valid for the record/status.

---

## Step 5: Diagnose blank variant edit form

If still blank locally after the shared form refactor, check:

```text
browser console
Rails logs
Stimulus controller registration
CSS display rules
Turbo/frame behavior
empty product/category/condition collections
branch/server mismatch
```

---

# Out of Scope

This work should not include:

```text
removing legacy resource routes
rebuilding the new item wizard
changing catalog/product/variant schema
adding inventory ledger behavior
changing pricing model behavior
replacing ItemPresenter
major navigation redesign outside item management
```

---

# Summary

The app already has the right read hub:

```text
ItemsController#show with item tabs
```

The remaining work is to make catalog item, product, and product variant mutation flows behave like subflows of the item page.

The preferred UX is:

```text
Start on item tab
Open focused edit/create form
Save/cancel
Return to same item tab
Highlight the affected record when useful
```

The legacy resource pages can remain, but they should stop being the primary return destination for item-tab workflows.

```
```
