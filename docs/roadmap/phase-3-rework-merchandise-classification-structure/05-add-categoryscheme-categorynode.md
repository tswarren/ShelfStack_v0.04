
# Add CategoryScheme, CategoryNode, and Categorization for topical/reporting classifications

## Summary

Add a flexible category taxonomy model so ShelfStack can support multiple classification schemes instead of one overloaded category list.

## Concepts

`CategoryScheme` = named classification system.

Examples:

- Bookstore Topics
- Nonbook Sections
- ABA Reporting Categories
- Website Browse Categories
- Cafe Categories
- Internal Reporting Categories

`CategoryNode` = a category inside a scheme.

Examples:

- Biography
- Fiction
- History / Military
- Stationery / Notebooks
- Cafe / Bakery
- New Book Sales
- Used Book Sales

`Categorization` = assignment of a catalog item, product, or variant to a category node.

## Suggested schema

```ruby
create_table :category_schemes do |t|
  t.string :name, null: false
  t.string :code, null: false
  t.string :purpose, null: false
  t.boolean :active, null: false, default: true
  t.timestamps
end

create_table :category_nodes do |t|
  t.references :category_scheme, null: false, foreign_key: true
  t.references :parent, foreign_key: { to_table: :category_nodes }
  t.string :name, null: false
  t.string :code, null: false
  t.integer :sort_order, null: false, default: 0
  t.boolean :active, null: false, default: true
  t.timestamps
end

create_table :categorizations do |t|
  t.references :category_node, null: false, foreign_key: true
  t.references :categorizable, polymorphic: true, null: false
  t.boolean :primary, null: false, default: false
  t.string :source
  t.timestamps
end
````

## Acceptance criteria

* Category schemes can be created and managed.
* Category nodes support hierarchy through `parent_id`.
* Catalog items, products, and/or product variants can be categorized.
* At least one starter scheme exists: “Store Sections / Topics.”
* The model supports future schemes without schema changes.
