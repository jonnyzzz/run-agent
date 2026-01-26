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
| `FACT` | Objective finding (code pattern, test result) |
| `DECISION` | Strategic choice made |
| `QUESTION` | Needs clarification |
| `ANSWER` | Response to `QUESTION` (requires `relatesTo`) |
| `PROGRESS` | Status update |
| `ERROR` | Failure report (critical issues requiring escalation) |
| `COMPLETE` | Task finished |
| `TASK` | New task or assignment |
| `REVIEW` | Structured review output |

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
