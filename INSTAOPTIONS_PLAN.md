# InstaOptions Active Section Plan

> **Status**: No section active.
>
> To start a new section: name the section, then this file gets replaced with a fresh template per the lifecycle in [INSTAOPTIONS_FLOW.md](INSTAOPTIONS_FLOW.md).

---

## Template (used when a section starts)

Replace the entire file with the template below when picking up a new section.

```
# InstaOptions Active Section Plan

**Section**: <name from FLOW catalog>
**Started**: <YYYY-MM-DD>
**Included items**: <bullet list of follow-up items + spec gaps being addressed in this section>

## Reference triad

- **Spec**: [INSTAOPTIONS_FEATURE_README.md §10.x](INSTAOPTIONS_FEATURE_README.md) (line NNNN)
- **Visual**: `.claude/insta-options-qa/optionz-reference/NN-<screen>.png`
- **Data audit**: [INSTAOPTIONS_DATA_AUDIT.md Screen NN](INSTAOPTIONS_DATA_AUDIT.md) (line NN)

## Phase 1 — Analysis

### Files in scope
- <path 1> — <role>
- <path 2> — <role>

### Sub-processes touched (current vs target)
| Sub-process | Current behaviour | Target (per spec) | Gap |
|---|---|---|---|
| <name> | <as observed> | <as spec demands> | <what to change> |

### Patterns to reuse
- <existing widget/helper/util + its file path>

### Acceptance criteria (used as QA criteria in Phase 5)
- [ ] <criterion 1>
- [ ] <criterion 2>

## Phase 2 — Step-by-step plan

1. **<file path>** — <one-line concrete change>
2. **<file path>** — <one-line concrete change>
3. **<file path>** — <one-line concrete change>

### Risks
- <risk + mitigation>

## Phase 3 — Chat explanation

Posted in chat at <timestamp>. User acked at <timestamp>.

## Phase 4 — Implementation log

| Step | File | Result |
|---|---|---|
| 1 | <path> | edit landed, `flutter analyze` clean |
| 2 | <path> | edit landed, `flutter analyze` clean |

## Phase 5 — QA brief + report

### Brief sent to `general-purpose` agent

```
<full brief text per FLOW QA template>
```

### Report received

```
<paste agent's final message verbatim>
```

## Phase 6 — Fixes from QA

| Issue | Fix | Re-QA result |
|---|---|---|
| <observed> | <file + change> | pass / fail |

## Phase 7 — Commit + HANDOFF update

- **Commit**: `instaoptions(<section-name>): <summary>` — `<hash>`
- **HANDOFF changes**:
  - Checked off: <items>
  - New caveats: <bullets>
  - Phase row update: <if applicable>
- **PLAN archived to**: `.claude/insta-options-qa/plans/<section-name>.md`
- **PLAN reset**: this file restored to "no section active".
```
