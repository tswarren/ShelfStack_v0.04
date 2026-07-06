# ShelfStack Component Catalog — Recommended Full List



Assumption: keep the current **ERB \+ `.ss-*` CSS** approach, but formalize it into reusable Rails partials or ViewComponents.

Suggested convention:

| Layer | Convention |
| :---- | :---- |
| CSS classes | `.ss-component-name`, `.ss-component-name__element`, `.ss-component-name--variant` |
| Rails partials | `shared/ui/_component_name.html.erb` |
| Optional ViewComponent class | `Ui::ComponentNameComponent` |
| Domain-specific components | `shared/<domain>/_component_name.html.erb` or `Domain::ComponentNameComponent` |

---

# 1\. Foundation components

| Component | Description | Use case | Variations | Suggested CSS/code names |
| :---- | :---- | :---- | :---- | :---- |
| **Design Tokens** | Central color, spacing, radius, shadow, typography, and density variables. | Ensures visual consistency across all components. | color, radius, spacing, shadow, font, line-height, density | `:root`, `--color-*`, `--radius-*`, `--shadow-*`, `--space-*`, `--line-*` |
| **Typography** | Standard text hierarchy and body text rules. | Headings, page titles, descriptions, labels, helper text. | heading, body, muted, subtle, eyebrow, mono/tabular | `.ss-heading`, `.ss-text-muted`, `.ss-text-subtle`, `.ss-eyebrow`, `.ss-tabular` |
| **Link** | Standard inline and action links. | Navigation, row actions, “Back,” “Cancel,” “View details.” | inline, quiet, button-like, danger, external | `.ss-link`, `.ss-link--quiet`, `.ss-link--danger`, `.ss-btn-link`; `shared/ui/link` |
| **Button** | Button or button-like action. | Forms, page actions, workflow actions, destructive actions. | primary, secondary, tertiary, danger, small, icon, full-width, link | `.ss-btn`, `.ss-btn-primary`, `.ss-btn-secondary`, `.ss-btn-tertiary`, `.ss-btn-danger`, `.ss-btn-small`; `shared/ui/button` |
| **Separator** | Visual or semantic divider. | Divide card sections, dropdown groups, form groups. | horizontal, vertical, subtle, strong | `.ss-separator`, `.ss-separator--vertical`, `.ss-separator--subtle`; `shared/ui/separator` |
| **Icon** | Standard inline icon treatment. | Buttons, badges, alerts, empty states, status rows. | leading, trailing, standalone, status | `.ss-icon`, `.ss-icon--leading`, `.ss-icon--status`; `shared/ui/icon` |
| **Avatar** | User/person representation with fallback initials. | Header user menu, audit events, customer/customer contact displays. | image, initials, small, large, muted | `.ss-avatar`, `.ss-avatar--initials`, `.ss-avatar--sm`; `shared/ui/avatar` |

---

# 2\. App shell and layout

| Component | Description | Use case | Variations | Suggested CSS/code names |
| :---- | :---- | :---- | :---- | :---- |
| **App Shell** | Overall application frame. | Header, nav, main content, footer, overlay regions. | default, focused/session, POS/register | `.ss-app-shell`, `.ss-app-shell--focused`, `.ss-app-shell--pos`; `layouts/application`, `layouts/session` |
| **App Chrome** | Sticky header/nav wrapper. | Keeps global search/navigation available. | sticky, static, compact | `.ss-app-chrome`, `.ss-app-chrome--sticky`; `shared/ui/app_chrome` |
| **Header** | Top identity/context/search/action bar. | Logo, store/workstation, global search, user menu. | default, compact, focused | `.ss-header`, `.ss-header__left`, `.ss-header__search`, `.ss-header__actions`; `layouts/header` |
| **Navigation Bar** | Primary workspace navigation. | Dashboard, Items, POS, Buybacks, Inventory, Customers, Reports, Setup. | primary, compact, grouped, disabled item | `.ss-nav`, `.ss-nav__item`, `.ss-nav__item--active`, `.ss-nav__item--disabled`; `layouts/nav` |
| **Sidebar** | Secondary workspace navigation. | Inventory subnav, Setup subnav, Reports categories. | fixed, sticky, collapsible, compact | `.ss-sidebar`, `.ss-sidebar__section`, `.ss-sidebar__item`; `shared/ui/sidebar` |
| **Footer** | Bottom shell information/actions. | Version, copyright, lock session. | default, three-zone, compact, hidden-print | `.ss-footer`, `.ss-footer__left`, `.ss-footer__center`, `.ss-footer__right`; `layouts/footer` |
| **Main Container** | Page content wrapper. | Standard max-width and page padding. | default, wide, POS-wide, narrow | `.ss-main`, `.ss-main--wide`, `.ss-main--narrow`, `.ss-pos-main` |
| **Page Header** | Page-level title/context/action block. | Index/detail/report/workflow pages. | simple, with actions, with description, with status, compact | `.ss-page-header`, `.ss-page-header__title`, `.ss-page-actions`; `shared/ui/page_header` |
| **Section Header** | Header within a page/card. | “Line items,” “Customer details,” “Vendor sources.” | with actions, compact, subtle | `.ss-section-header`, `.ss-section-title`, `.ss-section-actions`; `shared/ui/section_header` |
| **Card** | Contained surface with optional header/content/footer. | Setup cards, dashboard tiles, forms, details. | default, muted, compact, strong, clickable | `.ss-card`, `.ss-card__header`, `.ss-card__body`, `.ss-card__footer`; `shared/ui/card` |
| **Surface** | Generic reusable panel background. | Lower-level layout block used by other components. | plain, muted, glass, compact, strong | `.ss-surface`, `.ss-surface--plain`, `.ss-surface--muted`, `.ss-surface--strong` |
| **Stack** | Vertical layout utility. | Consistent spacing between child elements. | xs, sm, md, lg, start | `.ss-stack`, `.ss-stack--sm`, `.ss-stack--lg` |
| **Grid** | Responsive layout utility. | Card grids, form grids, metric grids. | auto-fit, two-column, three-column, dense | `.ss-grid`, `.ss-grid--2`, `.ss-grid--auto`, `.ss-card-grid` |
| **Action Row** | Horizontal action grouping. | Page actions, form buttons, detail actions, row actions. | start, end, between, loose, compact | `.ss-action-row`, `.ss-action-row--end`, `.ss-action-row--between`; `shared/ui/action_row` |

---

# 3\. Form and input components

| Component | Description | Use case | Variations | Suggested CSS/code names |
| :---- | :---- | :---- | :---- | :---- |
| **Form** | Standard form container. | Setup CRUD, login, POS forms, PO/receipt entry. | default, card, inline, compact, dense | `.ss-form`, `.ss-form-card`, `.ss-form--compact`; `shared/ui/form` |
| **Form Actions** | Standard submit/cancel/action area. | Save/cancel buttons, workflow submission. | start, end, between, sticky-bottom | `.ss-form-actions`, `.ss-form-actions--end`; `shared/ui/form_actions` |
| **Field** | Wrapper for one input, label, help, and errors. | Every standard form field. | required, invalid, disabled, inline, compact | `.ss-field`, `.ss-field--required`, `.ss-field--invalid`; `shared/ui/field` |
| **Fieldset** | Group of related fields with title/description. | Address, pricing, vendor terms, tax settings. | default, compact, bordered, inline | `.ss-fieldset`, `.ss-fieldset__legend`, `.ss-fieldset__description`; `shared/ui/fieldset` |
| **Label** | Text label for form fields. | All inputs/selects/checks/radios. | required, optional, inline, subtle | `.ss-label`, `.ss-field-label`, `.ss-label--required`; `shared/ui/label` |
| **Help Text** | Supplemental instruction below/near a field. | Password rules, SKU hints, import help. | normal, subtle, warning | `.ss-help`, `.ss-hint`, `.ss-field-help`; `shared/ui/help_text` |
| **Field Error** | Field-specific validation message. | Failed form submission, client/server validation. | error, warning | `.ss-field-error`, `.ss-field-warning`; `shared/ui/field_error` |
| **Input** | Standard text-like input. | Text, number, email, password, search. | text, password, search, number, money, compact | `.ss-input`, `.ss-input--search`, `.ss-input--money`, `.ss-input--compact`; `shared/ui/input` |
| **Masked Input** | Input with formatting mask. | ISBN, SKU, phone, ZIP/postal code, money, percent. | ISBN, money, percent, phone, postal, date | `.ss-input-mask`, `.ss-input-mask--isbn`; `shared/ui/masked_input` |
| **Textarea** | Multi-line text field. | Notes, descriptions, audit comments, customer requests. | default, compact, monospace, resize-none | `.ss-textarea`, `.ss-textarea--compact`; `shared/ui/textarea` |
| **Checkbox** | Boolean include/exclude control. | Include inactive, taxable, returnable, selected rows. | default, inline, card, disabled | `.ss-checkbox`, `.ss-checkbox-field`; `shared/ui/checkbox` |
| **Checkbox Group** | Group of multiple checkbox options. | Role permissions, filter options, category selections. | stacked, inline, grid, card-list | `.ss-checkbox-group`, `.ss-choice-list`; `shared/ui/checkbox_group` |
| **Radio Group** | Single-choice group. | Fulfillment choice, receipt disposition, tender type. | stacked, inline, card-list, segmented | `.ss-radio-group`, `.ss-radio`, `.ss-choice-option`; `shared/ui/radio_group` |
| **Switch** | Persistent on/off setting. | Enabled/disabled, active/inactive, setting toggles. | default, small, with-label, disabled | `.ss-switch`, `.ss-switch--sm`; `shared/ui/switch` |
| **Toggle** | Button-like two-state control. | Compact mode, show/hide options, selected state. | pressed, unpressed, icon-only, small | `.ss-toggle`, `.ss-toggle--pressed`; `shared/ui/toggle` |
| **Toggle Group** | Set of toggle buttons for mode/filter selection. | All/open/closed filters, view modes, line states. | single-select, multi-select, compact | `.ss-toggle-group`, `.ss-toggle-group__item`; `shared/ui/toggle_group` |
| **Native Select** | Styled native HTML select. | Small static lists: store, tax category, status. | default, compact, invalid, disabled | `.ss-select`, `.ss-select--native`; `shared/ui/native_select` |
| **Select** | Styled select-like picker. | Enhanced option picking where native select is too limiting. | single, grouped, searchable later | `.ss-select`, `.ss-select-trigger`, `.ss-select-menu`; `shared/ui/select` |
| **Combobox** | Searchable autocomplete picker. | Product variant lookup, customer lookup, vendor lookup, category node lookup. | single, multi, async, with preview, scanner-friendly | `.ss-combobox`, `.ss-combobox__input`, `.ss-combobox__results`; `shared/ui/combobox` |
| **Lookup Panel** | Domain-specific search/select panel. | POS line lookup, customer lookup, variant lookup, pickup lookup. | variant, customer, vendor, stored-value, receipt | `.ss-lookup-panel`, `.ss-lookup-result`, `.ss-lookup-empty`; `shared/ui/lookup_panel` |
| **Date Picker** | Date input with picker behavior. | Reports, PO dates, receipt dates, audit filters. | single date, date range, compact | `.ss-date-picker`, `.ss-date-range`; `shared/ui/date_picker` |
| **File Input** | Upload input with consistent styling. | Ingram import, future catalog/vendor imports. | default, drag area, compact, with file summary | `.ss-file-input`, `.ss-upload-zone`; `shared/ui/file_input` |
| **Validator** | Visual validation state system. | Client/server validation styling. | valid, invalid, warning, success | `.ss-valid`, `.ss-invalid`, `.ss-field--valid`, `.ss-field--invalid` |

---

# 4\. Feedback, status, and messaging

| Component | Description | Use case | Variations | Suggested CSS/code names |
| :---- | :---- | :---- | :---- | :---- |
| **Alert** | Inline callout that remains in page flow. | Warning panels, unmatched receipt lines, missing vendor source. | info, success, warning, error, neutral | `.ss-alert`, `.ss-alert--warning`, `.ss-alert--error`; `shared/ui/alert` |
| **Flash Message** | Server-driven request result message. | “Saved,” “Could not post receipt,” “Logged out.” | notice, warning, alert/error | `.flash`, `.flash-notice`, `.flash-warning`, `.flash-alert`; `shared/ui/flash_region` |
| **Toast** | Temporary overlay notification. | Turbo actions, successful inline updates, background result. | success, warning, error, info, undo action | `.ss-toast-region`, `.ss-toast`, `.ss-toast--success`; `shared/ui/toast` |
| **Empty State** | Display when there is no data/content. | Empty tables, no search results, no open demand. | simple, with action, with illustration/icon, compact | `.ss-empty-state`, `.ss-empty-state__actions`; `shared/ui/empty_state` |
| **Access Notice** | Permission/access-denied message. | Locked-out pages for POS, Items, Setup, etc. | standard, with permission key, with recovery content | `.ss-access-notice`, `.ss-access-notice__actions`; `shared/ui/access_notice` |
| **Progress** | Shows task completion. | Import progress, sourcing cascade, setup completion. | bar, circular, indeterminate, stepped | `.ss-progress`, `.ss-progress__bar`, `.ss-progress--indeterminate`; `shared/ui/progress` |
| **Skeleton / Loading** | Placeholder while content loads. | Turbo frames, lookups, metadata import, report loading. | text, card, table rows, lookup result | `.ss-skeleton`, `.ss-skeleton-row`, `.ss-skeleton-card`; `shared/ui/skeleton` |
| **Tooltip** | Small explanatory popup on hover/focus. | Disabled actions, icon-only buttons, field help. | default, warning, keyboard-focusable | `.ss-tooltip`, `.ss-tooltip-trigger`; `shared/ui/tooltip` |
| **Status Dot** | Compact state indicator. | Online/offline, active/inactive, posted/draft. | success, warning, error, muted, info | `.ss-status-dot`, `.ss-status-dot--success`; `shared/ui/status_dot` |
| **Badge** | Small label-like display. | Counts, tags, categories, short states. | neutral, primary, gold, success, warning, error | `.ss-badge`, `.ss-badge--warning`; `shared/ui/badge` |
| **Status Badge** | Badge specifically representing record state. | Draft, submitted, posted, cancelled, active, inactive. | draft, active, inactive, posted, partial, cancelled, closed | `.ss-status-badge`, `.status-draft`, `.status-posted`; `shared/ui/status_badge` |
| **Pill** | Rounded compact metadata label. | Filters, tags, classifications, subjects. | neutral, primary, gold, removable | `.ss-pill`, `.ss-pill--primary`, `.ss-pill--removable`; `shared/ui/pill` |

---

# 5\. Dialogs, overlays, and menus

| Component | Description | Use case | Variations | Suggested CSS/code names |
| :---- | :---- | :---- | :---- | :---- |
| **Dialog** | Modal window for focused interaction. | Edit price, edit classification, create vendor source. | small, medium, large, form-dialog | `.ss-dialog`, `.ss-dialog__header`, `.ss-dialog__body`, `.ss-dialog__footer`; `shared/ui/dialog` |
| **Alert Dialog** | Interruptive confirmation requiring decision. | Post receipt, void transaction, cancel PO, delete/deactivate. | warning, danger, irreversible, confirmation text | `.ss-alert-dialog`, `.ss-alert-dialog--danger`; `shared/ui/alert_dialog` |
| **Sheet / Drawer** | Side panel complementing current page. | Variant operations, quick customer view, receipt matching, POS lookup. | right, left, bottom, wide, full-height | `.ss-sheet`, `.ss-drawer`, `.ss-drawer--right`; `shared/ui/sheet` or `shared/ui/drawer` |
| **Dropdown Menu** | Button-triggered menu of actions. | User menu, row actions, “More actions.” | default, right-aligned, danger group, with icons | `.ss-dropdown`, `.ss-dropdown-trigger`, `.ss-dropdown-menu`, `.ss-dropdown-item`; `shared/ui/dropdown_menu` |
| **Context Menu** | Right-click or long-press menu. | Advanced desktop row actions. | row-actions, compact, disabled items | `.ss-context-menu`; `shared/ui/context_menu` |
| **Hover Card** | Preview panel for link/card content. | Preview customer, variant availability, vendor source, allocation. | simple, rich, delayed, compact | `.ss-hover-card`, `.ss-hover-card__content`; `shared/ui/hover_card` |
| **Popover** | Rich floating content triggered by button. | Advanced filters, quick help, lightweight pickers. | default, form popover, help popover | `.ss-popover`, `.ss-popover-trigger`, `.ss-popover-content`; `shared/ui/popover` |
| **Clipboard / Copy Button** | Copy value to clipboard. | ISBN, SKU, PO number, receipt number, error detail. | icon-only, with label, copied state | `.ss-copy-button`, `.ss-copy-button--copied`; `shared/ui/copy_button` |

---

# 6\. Navigation and disclosure

| Component | Description | Use case | Variations | Suggested CSS/code names |
| :---- | :---- | :---- | :---- | :---- |
| **Breadcrumbs** | Shows current hierarchy/path. | Setup nested screens, item/product/variant, PO/receipt detail. | default, compact, truncated | `.ss-breadcrumbs`, `.ss-breadcrumbs__item`; `shared/ui/breadcrumbs` |
| **Tabs** | Layered content panels, one visible at a time. | Item detail, customer detail, setup detail pages. | horizontal, vertical, compact, with badges | `.ss-tabs`, `.ss-tab-list`, `.ss-tab`, `.ss-tab-panel`; `shared/ui/tabs` |
| **Accordion** | Multiple expandable sections, usually related. | Mobile item detail, grouped setup help, report explanations. | single-open, multi-open, compact | `.ss-accordion`, `.ss-accordion-item`, `.ss-accordion-trigger`; `shared/ui/accordion` |
| **Collapsible** | One independently expandable section. | Advanced filters, recovery instructions, audit details, optional notes. | open, closed, compact, bordered | `.ss-collapsible-panel`, `.ss-collapsible-panel__body`; `shared/ui/collapsible` |
| **Pagination** | Page navigation for long lists. | Setup indexes, reports, customers, inventory balances. | simple, full, compact, with summary | `.ss-pagination`, `.ss-pagination__summary`, `.ss-pagination__links`; `shared/ui/pagination` |
| **Steps** | Visual process progress. | Add Item, import, receiving, demand-to-PO, setup wizard. | horizontal, vertical, numbered, status-based | `.ss-steps`, `.ss-step`, `.ss-step--active`, `.ss-step--complete`; `shared/ui/steps` |
| **Shortcut Key** | Displays keyboard shortcut. | POS command hints, buyer workbench shortcuts. | single key, combo, compact | `.ss-shortcut-key`, `.ss-kbd`; `shared/ui/shortcut_key` |
| **Command Palette** | Global searchable action menu. | Future fast navigation/actions for expert users. | global, module-scoped, searchable | `.ss-command`, `.ss-command-palette`; `shared/ui/command_palette` |

---

# 7\. Data display components

| Component | Description | Use case | Variations | Suggested CSS/code names |
| :---- | :---- | :---- | :---- | :---- |
| **Table** | Basic responsive table. | Static data, detail line tables, simple lists. | default, compact, dense, sticky header, numeric columns | `.ss-table`, `.ss-table--compact`, `.ss-table--dense`, `.ss-table--sticky`; `shared/ui/table` |
| **Data Table** | Interactive table with filters/search/sort/pagination. | Inventory balances, demand queue, PO index, setup indexes, customer search. | searchable, sortable, paginated, selectable, bulk-actions | `.ss-data-table`, `.ss-data-table-toolbar`, `.ss-data-table-pagination`; `shared/ui/data_table` |
| **Row Actions** | Standard row-level action area. | Edit, view, deactivate, receive, post, cancel. | inline, dropdown, icon-only, danger group | `.ss-row-actions`, `.ss-row-actions--dropdown`; `shared/ui/row_actions` |
| **Metric Card / Stat** | Displays one important number. | Reports, dashboards, register summary, inventory value. | default, money, count, percent, warning, compact | `.ss-metric-card`, `.ss-stat`, `.ss-stat--money`; `shared/ui/metric_card` |
| **Metric Strip** | Group of metric cards. | Report summary, POS session totals, buyer workbench summary. | auto-fit, compact, dense | `.ss-metric-strip`, `.ss-metric-strip--compact`; `shared/ui/metric_strip` |
| **List / List Row** | Mobile-friendly list alternative to tables. | Search results, customer activity, recent transactions. | simple, rich, selectable, with actions | `.ss-list`, `.ss-list-row`, `.ss-list-row__actions`; `shared/ui/list` |
| **Timeline** | Chronological activity display. | Audit events, inventory movement, customer contact history, PO lifecycle. | simple, detailed, compact, with status | `.ss-timeline`, `.ss-timeline-item`, `.ss-timeline-marker`; `shared/ui/timeline` |
| **Definition List / Summary** | Label-value summary block. | Product details, customer profile, receipt summary. | two-column, compact, bordered | `.ss-summary`, `.ss-summary--compact`; `shared/ui/summary_list` |
| **Carousel** | Swipeable sequence of visual items. | Catalog cover images, product image previews. | image, card, compact | `.ss-carousel`, `.ss-carousel-item`; `shared/ui/carousel` |
| **Code Block** | Monospace block for commands/config. | Setup recovery instructions, developer/admin recovery notes. | inline, block, copyable | `.ss-code`, `.ss-code-block`; `shared/ui/code_block` |

---

# 8\. Domain-specific ShelfStack components

These are not generic UI-library components, but they are important enough to formalize because ShelfStack will reuse them heavily.

## Item/catalog components

| Component | Description | Use case | Variations | Suggested CSS/code names |
| :---- | :---- | :---- | :---- | :---- |
| **Item Hero** | Prominent title/metadata block for an item. | Item detail page. | with cover, no cover, compact | `.ss-item-hero`, `.ss-item-title`; `shared/items/item_hero` |
| **Variant Card** | Summary of a product variant. | Item detail, search results, operations drawer. | available, unavailable, inactive, compact | `.ss-variant-card`, `.ss-variant-card--inactive`; `shared/items/variant_card` |
| **Availability Badge** | Compact stock/availability status. | Item/variant/search/POS lookup. | available, low, out, negative, on-order, reserved | `.ss-availability-badge`, `.ss-availability-badge--out`; `shared/items/availability_badge` |
| **Identifier List** | ISBN/SKU/barcode/house code display. | Catalog item/product/variant detail. | primary, secondary, copyable | `.ss-identifier-list`, `.ss-identifier`; `shared/items/identifier_list` |
| **Metadata Panel** | Catalog metadata block. | External metadata, catalog details, imported records. | source, local, comparison | `.ss-metadata-panel`, `.ss-metadata-source`; `shared/items/metadata_panel` |
| **Vendor Source Card** | Product/vendor or variant/vendor summary. | Items, Orders, Setup vendor-source screens. | preferred, inactive, missing, warning | `.ss-vendor-source-card`, `.ss-vendor-source-card--preferred`; `shared/vendors/vendor_source_card` |

## Inventory components

| Component | Description | Use case | Variations | Suggested CSS/code names |
| :---- | :---- | :---- | :---- | :---- |
| **Stock Summary** | On-hand/value/availability summary. | Inventory variant detail, item detail, inventory balance rows. | store-level, enterprise, compact | `.ss-stock-summary`, `.ss-stock-summary-card`; `shared/inventory/stock_summary` |
| **Stock Movement Row** | Standard inventory ledger row. | Inventory movement timeline/table. | receipt, sale, adjustment, RTV, buyback | `.ss-stock-movement-row`, `.ss-stock-movement-row--receipt`; `shared/inventory/stock_movement_row` |
| **Quantity Badge** | Numeric quantity with semantic state. | On hand, on order, allocated, negative. | positive, zero, negative, reserved, on-order | `.ss-quantity-badge`, `.ss-quantity-badge--negative`; `shared/inventory/quantity_badge` |
| **Inventory Warning Panel** | Warning about inventory risk. | Negative stock, unposted adjustments, missing cost. | negative, missing-cost, integrity, discrepancy | `.ss-inventory-warning`, `.ss-inventory-warning--negative`; `shared/inventory/warning_panel` |

## POS components

| Component | Description | Use case | Variations | Suggested CSS/code names |
| :---- | :---- | :---- | :---- | :---- |
| **POS Workspace** | Main register work surface. | Active transaction screen. | sale, return, suspended, completed | `.ss-pos-workspace`, `.ss-pos-workspace--return`; `shared/pos/workspace` |
| **POS Command Bar** | Scan/search/action entry row. | Add item, add return, add open-ring, route command. | default, compact, scanner-focused | `.ss-pos-command-bar`, `.ss-pos-scan-row`; `shared/pos/command_bar` |
| **Cart Line** | Transaction line display/edit row. | POS transaction/cart. | sale, return, discount, tax override, voided | `.ss-pos-cart-line`, `.ss-pos-cart-line--return`; `shared/pos/cart_line` |
| **Tender Panel** | Payment/tender entry area. | POS checkout. | cash, card, stored value, mixed tender | `.ss-pos-tender-panel`, `.ss-pos-tender-row`; `shared/pos/tender_panel` |
| **Totals Panel** | Transaction totals summary. | POS workspace, receipt, register report. | sale, return, tax-exempt, discounted | `.ss-pos-totals-panel`, `.ss-pos-totals-list`; `shared/pos/totals_panel` |
| **Receipt Template** | Printable receipt/slip layout. | POS receipt, buyback receipt, stored value slip. | receipt, slip, reprint, customer copy | `.ss-receipt`, `.ss-receipt-actions`; `shared/pos/receipt` |

## Purchasing/orders components

| Component | Description | Use case | Variations | Suggested CSS/code names |
| :---- | :---- | :---- | :---- | :---- |
| **Document Header** | Header for PO/receipt/RTV/adjustment documents. | Purchasing/receiving workflows. | draft, submitted, posted, cancelled, closed | `.ss-document-header`, `.ss-document-header__meta`; `shared/documents/document_header` |
| **Line Entry Table** | Editable table for document lines. | PO, receipt, RTV, inventory adjustment. | purchasing, receiving, adjustment, compact | `.ss-line-entry-table`, `.ss-purchasing-table`; `shared/documents/line_entry_table` |
| **Document Status Badge** | Status badge for operational documents. | PO, receipt, RTV, adjustment, sourcing run. | draft, submitted, ordered, partial, posted, cancelled, closed | `.ss-document-status`, `.ss-status-badge.status-posted`; `shared/documents/status_badge` |
| **Receiving Quantity Fields** | Accepted/rejected/damaged/backordered buckets. | Receipt line entry. | accepted, damaged, rejected, cancelled, backordered | `.ss-receiving-qty-fields`, `.ss-receiving-qty`; `shared/orders/receiving_quantity_fields` |
| **Receipt Match Card** | Suggested/selected receipt line match. | Receipt matching workflow. | suggested, selected, conflict, unmatched | `.ss-receipt-match-card`, `.ss-receipt-match-card--conflict`; `shared/orders/receipt_match_card` |
| **Vendor Cascade Timeline** | Shows sourcing attempts through vendors. | Sourcing run detail. | pending, submitted, responded, cascaded, cancelled | `.ss-vendor-cascade`, `.ss-vendor-cascade-step`; `shared/sourcing/vendor_cascade` |

## Demand/customer components

| Component | Description | Use case | Variations | Suggested CSS/code names |
| :---- | :---- | :---- | :---- | :---- |
| **Demand Card** | Summary of a demand line/customer request. | Demand queue, customer detail, item detail. | open, allocated, ordered, fulfilled, cancelled, expired | `.ss-demand-card`, `.ss-demand-card--allocated`; `shared/demand/demand_card` |
| **Allocation Card** | Demand allocation/reservation summary. | Demand detail, POS pickup, PO receiving. | stock, inbound, fulfilled, released, expired | `.ss-allocation-card`, `.ss-allocation-card--inbound`; `shared/demand/allocation_card` |
| **Customer Profile Header** | Customer identity/contact summary. | Customer detail, POS customer context. | active, inactive, with stored value, compact | `.ss-customer-profile-header`; `shared/customers/profile_header` |
| **Activity Timeline** | Customer/contact/action history. | Customer profile, audit history. | contact, demand, purchase, stored-value | `.ss-activity-timeline`, `.ss-activity-item`; `shared/customers/activity_timeline` |
| **Stored Value Balance Card** | Stored value account balance/status. | POS, customer account detail, lookup result. | active, suspended, closed, low/zero balance | `.ss-stored-value-card`, `.ss-balance-card`; `shared/stored_value/balance_card` |

## Buyback components

| Component | Description | Use case | Variations | Suggested CSS/code names |
| :---- | :---- | :---- | :---- | :---- |
| **Buyback Workspace** | Main buyback session surface. | Buyback session screen. | intake, proposal, decision, completed, voided | `.ss-buyback-workspace`; `shared/buybacks/workspace` |
| **Buyback Line Card** | One item in a buyback session. | Buyback intake/decision workflow. | pending, accepted, declined, donated, overridden | `.ss-buyback-line-card`, `.ss-buyback-line-card--accepted`; `shared/buybacks/line_card` |
| **Offer Summary** | Cash/trade-credit/accepted totals. | Buyback session, proposal print. | cash, trade credit, mixed, donation | `.ss-offer-summary`, `.ss-buyback-summary-card`; `shared/buybacks/offer_summary` |

---

# 9\. Print-specific components

| Component | Description | Use case | Variations | Suggested CSS/code names |
| :---- | :---- | :---- | :---- | :---- |
| **Print Page** | Print-optimized full page. | Register summary, reports, proposal, statements. | letter, receipt-width, compact | `.ss-print-page`, `.ss-print-page--letter`, `.ss-print-page--receipt`; `shared/print/page` |
| **Print Header** | Print-only report/document heading. | Reports, register summary, PO/receipt printouts. | report, receipt, slip | `.ss-print-header`, `.ss-print-title`; `shared/print/header` |
| **Print Section** | Print-friendly content section. | Tax report, register summary, drawer block. | bordered, compact, totals | `.ss-print-section`, `.ss-print-section--totals`; `shared/print/section` |
| **Receipt/Slip Layout** | Narrow receipt-printer layout. | POS receipts, stored value slips, trade credit slips. | receipt, stored-value, buyback | `.ss-receipt`, `.ss-slip`, `.ss-slip--stored-value`; `shared/print/receipt` |

---

# Recommended implementation priority

## Priority 1 — must formalize first

These will immediately improve the global/auth/access review work:

```
Button
Link
Form
Field
Input
Select / Native Select
Alert
Toast
Access Notice
Session Card
Card / Surface
Page Header
Dropdown Menu
Dialog
Alert Dialog
```

## Priority 2 — high operational value

```
Data Table
Pagination
Empty State
Combobox
Lookup Panel
Sheet / Drawer
Tabs
Breadcrumbs
Status Badge
Metric Card
Document Header
Line Entry Table
```

## Priority 3 — workflow polish

```
Steps
Progress
Skeleton
Tooltip
Collapsible
Accordion
Timeline
Switch
Toggle Group
File Input
Date Picker
Masked Input
```

## Priority 4 — useful later

```
Avatar
Hover Card
Clipboard / Copy Button
Shortcut Key
Command Palette
Context Menu
Popover
Carousel
Theme Toggle
```

---

# Practical next step

Create a first component catalog document:

```
docs/design/components.md
```

Start each component with this template:

```
## Button

**Purpose:** Trigger an action.

**Use for:** Save, submit, post, cancel, search, open detail.

**Do not use for:** Static status labels or navigation that should be a normal link.

**Variants:**
- Primary: one main action per page/section.
- Secondary: important alternate action.
- Tertiary: cancel, back, close, logout, lock session.
- Danger: destructive or irreversible action.
- Link: low-emphasis inline action.

**CSS:**
- `.ss-btn`
- `.ss-btn-primary`
- `.ss-btn-secondary`
- `.ss-btn-tertiary`
- `.ss-btn-danger`
- `.ss-btn-link`
- `.ss-btn-small`

**Rails partial:**
- `shared/ui/_button.html.erb`
```

This lets the team standardize view-by-view without importing an external design system prematurely.  