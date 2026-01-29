# Message Bus

**Version:** v3 (file-based protocol)
**Purpose:** Central communication channel for all AI Agents.
**Protocol:** Append-only. Never delete or modify existing messages.

---

## Message Format Reference

```markdown
---
messageId: MSG-YYYYMMDD-HHMMSS-<agent>-<rand>
type: <FACT|DECISION|QUESTION|ANSWER|PROGRESS|ERROR|COMPLETE|TASK|REVIEW>
agent: <agent-type>-<role>-<instance>
timestamp: YYYY-MM-DDTHH:MM:SSZ
runId: <run_XXX>
taskId: <TASK-...>
relatesTo: <parent-messageId>
files: <optional list>
artifacts: <optional list>
---

<message content>

---
```

**Field Details:**
- `messageId`: `MSG-` + date + time + agent + short random suffix (example: `MSG-20260126-101500-claude-5f2`)
- `agent`: Format `<type>-<role>-<N>` (example: `claude-research-1`, `orchestrator`)
- `relatesTo`: Required for `ANSWER` messages, optional otherwise
- `runId` and `taskId`: Required for traceability

## Message Types

| Type | Purpose |
|------|---------|
| `FACT` | Objective finding |
| `DECISION` | Strategic choice |
| `QUESTION` | Needs clarification |
| `ANSWER` | Response to `QUESTION` (requires `relatesTo`) |
| `PROGRESS` | Status update |
| `ERROR` | Failure report |
| `COMPLETE` | Task finished |
| `TASK` | New task or assignment |
| `REVIEW` | Structured review output |

### REVIEW Template

```markdown
Scope: <files/modules>
Severity: <blocker/major/minor/nit>
Findings: <bulleted list with file refs>
Tests: <missing or recommended>
Recommendation: <action>
```

### ERROR Template

```markdown
## Error Report

**Task:** <task description>
**Attempts:**
1. Claude: <error summary>
2. Codex: <error summary>
3. Gemini: <error summary>

**Error Details:**
```
<last error output>
```

**Impact:** <what is blocked>
**Suggested Action:** <recommendation>
```

---

## Traceability Rules

1. Log all prompts and raw outputs in `runs/run_XXX/run.log`.
2. Save agent output in `runs/run_XXX/agent-logs/<agent>.txt`.
3. Save model inputs in `runs/run_XXX/prompts/`.
4. Include `taskId` in every message and plan item.
5. Include `runId` in commit messages for auditability.
6. Save review packets in `runs/run_XXX/artifacts/review-packet.md`.

---

## Messages

<!-- All messages below this line. Append only. Do not modify above messages. -->

---
messageId: MSG-00000000-000000-000
type: FACT
agent: template
timestamp: 0000-00-00T00:00:00Z
runId: run_000
taskId: TASK-000
---

Template initialized. When starting orchestration, append your first message below.
This placeholder message should remain for reference.

---
