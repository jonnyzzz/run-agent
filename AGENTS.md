# Project Agents Configuration

**Location:** Project root (`/AGENTS.md`)

This is the root agent configuration file. All subsystem AGENTS.md files inherit from this.

---

## Global Settings

| Setting | Value |
|---------|-------|
| **Build Tool** | `<gradle/maven/npm/other>` |
| **Test Framework** | `<junit/pytest/jest/other>` |
| **Language** | `<kotlin/java/typescript/python/other>` |
| **Code Style** | `<reference to style guide or config file>` |

---

## Available Agent Types

| Agent Type | Responsibilities | Preferred CLI |
|------------|------------------|---------------|
| **Orchestrator** | Task decomposition, coordination, synthesis | Claude Code |
| **Research** | Codebase exploration, documentation analysis | Any |
| **Implementation** | Code changes, new features, bug fixes | Codex (IntelliJ MCP) |
| **Review** | Code review, quality assurance | All (cross-validation) |
| **Test** | Test execution, coverage analysis | Codex (IntelliJ MCP) |
| **Debug** | Debugging failing tests, investigating issues | Codex (IntelliJ MCP) |

---

## Default Permissions

All agents inherit these permissions unless overridden:

### File Access

| Scope | Permission |
|-------|------------|
| `**/*.md` | Read |
| `src/**/*` | Read, Write |
| `tests/**/*` | Read, Write |
| `build/**/*` | Read |
| `*.config.*` | Read |

### Tool Access

| Tool | Access |
|------|--------|
| IntelliJ MCP Steroid | Full |
| Playwright MCP | Full |
| File operations | Full |
| Web search | Full |
| Bash commands | Build and test only |

---

## Project Conventions

### Code Style

- Follow existing patterns in the codebase
- Check `.editorconfig` for formatting rules
- Use IDE inspections to catch issues

### Git Commits

Format: `<type>(<scope>): <description>`

Types:
- `feat` - New feature
- `fix` - Bug fix
- `refactor` - Code refactoring
- `test` - Test changes
- `docs` - Documentation changes
- `chore` - Build/config changes

### Testing

- All new code must have tests
- Tests must pass before committing
- Use existing test patterns

---

## Subsystem Registry

| Subsystem | Path | AGENTS.md |
|-----------|------|-----------|
| `<name>` | `src/<path>` | `src/<path>/AGENTS.md` |
| `<name>` | `src/<path>` | `src/<path>/AGENTS.md` |

---

## Communication Protocol

All agents must:
1. Write significant findings to MESSAGE-BUS.md
2. Monitor MESSAGE-BUS.md for questions addressed to them
3. Log errors to ISSUES.md
4. Report completion via MESSAGE-BUS.md

See message-bus-mcp/AGENT-GUIDE.md for message format specification (or docs/v3/COMMUNICATION-TRACEABILITY.md for legacy file-based protocol).

---

## Customization Notes

<!--
Add project-specific notes here:
- Special build requirements
- CI/CD considerations
- External service dependencies
- Team conventions not covered above
-->
