# App Shell and POS Workspace Shell

ShelfStack has one global application shell. The top-level header and primary navigation should be consistent across POS and non-POS areas.

## Global app shell

The global app shell owns:

- logo placement
- store/workstation context
- global search
- user menu
- appearance switcher
- logout
- primary navigation
- active top-level nav state
- flash/toast behavior

Do not create a second POS-specific top-level header or primary navigation that duplicates the global shell.

## Implementation contract

Every normal app layout should emit the same shell contract:

```erb
<%= tag.body(**shelfstack_body_attributes(...)) do %>
  <%= link_to "Skip to content", "#main_content", class: "ss-skip-link" %>
  <%= render "layouts/header" %>
  <%= render "layouts/nav" %>
  <main id="main_content" class="...">
    ...
  </main>
<% end %>
```

The body contract owns:

- `data-ss-typeface`
- `data-ss-density`
- `data-ss-color-mode`
- `.ss-app-body`
- page/body context classes, such as `.ss-pos-body`

Use `content_for :main_class` for main-canvas width and `content_for :body_class` for page/body context. Do not create alternate top-level headers, navs, or body appearance mechanisms for domain areas.

## Appearance preference scope

The user-facing appearance control in this branch is **view mode**:

- Standard View
- Accessible View
- Compact View

View mode derives the active typeface and density profile. The shell emits these as `data-ss-typeface` and `data-ss-density` on `body`.

`appearance_color_mode` and `data-ss-color-mode` are present as plumbing for the shell contract, but full user-facing color mode switching and dark-mode QA are reserved for a later pass.

## POS workspace shell

POS-specific context belongs inside the POS workspace, below the global header and global navigation.

The POS workspace shell owns:

- POS/register/session status
- POS transaction context
- POS actions menu
- scan/command input
- sale/refund/pickup mode
- Open Ring and Gift Card quick actions
- POS-specific feedback, choices, and inline panels

## Recommended hierarchy

```text
Global Header
Global Navigation

POS Workspace Header
POS Command Bar
POS Transaction Workspace
```

## POS workspace header pattern

| Area | Contents |
| --- | --- |
| Left | POS/register/session details |
| Right | POS actions menu |

The POS workspace header should not repeat store/workstation/user identity because those belong in the global application header.

## POS command bar pattern

| Row | Contents |
| --- | --- |
| Command row | Scan/command input + sale/refund/pickup mode |
| Quick row | Open Ring, Gift Card, and other quick actions |
| Feedback row | POS choices, warnings, inline panels, and modals |

## Rule

Use one app header and one app nav everywhere. POS adds a specialized workspace below them; it does not replace or duplicate the global shell.
