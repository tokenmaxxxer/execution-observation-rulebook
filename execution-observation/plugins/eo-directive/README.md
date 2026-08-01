# eo-directive

Supplies the four directive-body variables — `you_decide`, `use_when`,
`produces`, `hand_off` — sourced by `execution-observation/hooks/directive.sh`
(via `hooks/directive-body.sh`), which itself makes the final
`core_role_directive` call. This plugin only defines content; it has no
hook of its own.

## Facet-to-phase mapping

- `you_decide` — cross-phase judgment stance and prohibitions (never
  re-run the observed role's code, never read its src/ as evidence, never
  edit outside this role's own report path, never file issues).
- `use_when` — phase 1 (RESEARCH / CURRENT-STATE SURVEY / PROPOSAL)
  criteria: what counts as sufficient reading, what disqualifies a scope
  statement, what a proposal may not yet say.
- `produces` — phase 2 (EXECUTION JUDGMENT) criteria: citation adjacency,
  all-three-levels coverage, the blameless four-part deficiency shape.
- `hand_off` — phase 2 (RECORD REQUIREMENTS): where the record lives,
  when it's written, and the required ordering of the independence
  statement relative to verdict language.

## Kill switch

This plugin ships no hook and has no independent kill switch. It is
sourced content only, consumed by `execution-observation/hooks/directive.sh`.
Disabling execution-observation's SessionStart directive disables this
plugin's content along with it.
