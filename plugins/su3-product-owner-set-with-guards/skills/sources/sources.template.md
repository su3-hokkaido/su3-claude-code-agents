# Sources

<!--
  Where the su3-product-owner-set skills and the main session find the
  documents that live outside this repository (Jira, Confluence, Notion,
  Nulab Backlog, Backstage, Asana, Google Docs, ...).
  Path: docs/policy/sources.md (fixed; do not move or rename).
  Import it from the repository's CLAUDE.md with the line
  `@docs/policy/sources.md` written there as plain text (without the
  backticks, not in a code block). Here it stays in backticks so that this
  file does not import itself.
  Only the Commander edits this file. Agents never edit it.
  Write commands, package specs and handles in this human part inside
  backticks, so that no "@" is read as an import.
  This file holds locations only. Never write tokens, passwords or API keys.
-->

- Owner: <Commander name>
- Last reviewed: <YYYY-MM-DD>

## 1. Purpose

This file says where the documents are. The main session reads it and fetches
them at run time through the MCP servers you connected yourself. Nothing is
indexed or cached: every run fetches again, read-only.

## 2. Entry fields

| Field | Required | Meaning |
|---|---|---|
| `id` | yes | Unique, lowercase, characters `a-z0-9-` |
| `role` | yes | What the resource is: `roadmap`, `backlog`, `meeting-notes`, `customer-feedback`, `spec`, `adr`, or free text. Several entries may share a role |
| `system` | yes | The tool: `jira`, `confluence`, `notion`, `backlog`, `gdocs`, `asana`, `backstage`, or free text |
| `locator` | yes | URL, project key, space key or folder |
| `filter` | no | A hint passed to the connector, for example a JQL string |
| `used-by` | no | Comma-separated skill or agent names. Empty means any |

## 3. Prerequisites

Connect the MCP server for each `system` you list, in your own Claude Code
settings. If no connected tool fits an entry, the entry is reported as
unreachable and the run goes on.

## 4. Entries

Add one entry per resource. The examples are commented out: remove the leading
`#` characters and edit them.

```sources
version: 1
# - id: product-backlog
#   role: backlog
#   system: jira
#   locator: https://example.atlassian.net/jira/software/projects/ABC
#   filter: "statusCategory != Done"
#   used-by: su3-backlog-manager
# - id: meeting-notes
#   role: meeting-notes
#   system: gdocs
#   locator: https://docs.google.com/document/d/EXAMPLE
```
