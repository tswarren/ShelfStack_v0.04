
# Add MerchandiseClass model for merchandise behavior defaults

## Summary

Add `MerchandiseClass` as the model responsible for broad merchandise behavior and operational defaults.

`MerchandiseClass` should represent how a sellable item behaves, not what the item is about.

## Examples

- General Trade Books
- Pro/Sci/Tech Books
- Used Books
- Bargain / Remainder Books
- Periodicals
- Recorded Music / Video / Games
- Sidelines
- Cafe
- Shipping
- Tickets
- Donations

## Suggested fields

Illustrative first-pass fields:

```ruby
create_table :merchandise_classes do |t|
  t.string  :name, null: false
  t.string  :code, null: false
  t.string  :default_pricing_model
  t.references :default_tax_category, foreign_key: { to_table: :tax_categories }
  t.integer :default_margin_target_bps
  t.integer :default_supplier_discount_bps
  t.boolean :has_list_price, null: false, default: true
  t.boolean :vendor_discounts_from_list_price, null: false, default: true
  t.boolean :store_marks_up_from_cost, null: false, default: false
  t.boolean :vendor_returnable_default, null: false, default: false
  t.boolean :used_sales_allowed, null: false, default: false
  t.boolean :buyback_allowed, null: false, default: false
  t.string  :default_sales_account_code
  t.boolean :active, null: false, default: true
  t.timestamps
end
````

Final schema may vary, but the model should support the operational defaults currently being overloaded into `Category`.

## Acceptance criteria

* `MerchandiseClass` model exists.
* Basic validations exist for name/code.
* Active/inactive behavior exists.
* Admin/setup CRUD exists or is scaffolded.
* Seed data includes starter merchandise classes for a typical bookstore.
* No existing category behavior is broken.
