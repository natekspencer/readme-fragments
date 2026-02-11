# README Fragments

This repo provides reusable headers, footers, and badges for all my Home Assistant and python repos.

## Usage

- Include `<!-- BEGIN AUTO-GENERATED HEADER -->` / `<!-- END AUTO-GENERATED HEADER -->`
- Include `<!-- BEGIN AUTO-GENERATED FOOTER -->` / `<!-- END AUTO-GENERATED FOOTER -->`
- Run `make readme` locally or via CI

## Headers

- `homeassistant`
- `python`

## Footers

- `support`
- `star-history`

## Design Notes (for Future Me)

This repository exists to keep README headers and footers consistent across
multiple repositories without duplication or manual edits.

If you're reading this months later and wondering "why not just edit the README?",
this is why:

### Core principles

- **Single source of truth**
  All shared README content lives here. Consuming repos supply _data_, not logic.

- **Generated sections are immutable**
  Anything between:
  <!-- BEGIN AUTO-GENERATED HEADER -->
  <!-- END AUTO-GENERATED HEADER -->

  or
  <!-- BEGIN AUTO-GENERATED FOOTER -->
  <!-- END AUTO-GENERATED FOOTER -->

  must never be edited manually.

- **Rolling major version**
  `@v1` is a moving target. It receives fixes and improvements.
  Only cut `v2` for breaking changes.

- **Structure here, content there**
  This repo defines layout and rules.
  Consuming repos inject content via inputs (e.g. custom badges).

### Why custom badges are inputs (not flags)

Badges like affiliate links, sponsors, or one-off integrations are **content**.
Encoding them here would create repo-specific logic and long-term tech debt.

Instead:

- This repo controls _where_ custom badges appear
- Consuming repos control _what_ they are

### Why CI fails on README drift

If CI fails with "README out of date", it means:

- the generated README differs from what's committed
- someone edited a managed section by hand
- or the fragments changed upstream

This is intentional.
Generated files must be regenerated, not patched.

### How to update READMEs locally

Every consuming repo supports:

```bash
make readme
```

This runs the same renderer as CI and updates the README deterministically.

### When to create v2

Only cut a new major version if you:

- change required inputs
- rename or remove headers/footers
- change marker syntax
- alter defaults in a way that changes output

Color tweaks, badge changes, and new optional features stay in v1.
