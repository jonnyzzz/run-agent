# run-agent.sh: The Missing Runtime for AI Development

## 1. Elevator Pitch
**run-agent.sh** is a lightweight, battle-tested orchestration framework that turns raw LLMs into a coordinated, parallel software development team. It combines a unified runner for launching isolated AI agents (Claude, Codex, Gemini) with a rigorous 13-stage workflow to take tasks from research to merged PR with full traceability.

## 2. Core Value Propositions

### 🚀 Agentic Swarm
Don't wait for one bot to finish. Spin up to **16 parallel AI agents** simultaneously. Separate concerns by having dedicated agents for research, implementation, and review working at the same time on the same codebase.

### 🧠 THE_PROMPT_v5.md: The Brain
This isn't just a script; it's a methodology. Included is a proven **13-stage orchestration workflow** that defines strict roles (Orchestrator, Research, Implementation, Review, Test, Debug, Monitor) and quality gates. It turns "chatting with AI" into a disciplined engineering process.

### 🕵️ Full Observability & Traceability
Stop guessing what the AI did. Every single agent run is isolated in its own folder (`runs/run_YYYYMMDD...`) containing:
- The exact **input prompt** used.
- Full **stdout/stderr** logs.
- **PID and exit codes** for process control.
- Execution context and working directory snapshots.

### 📢 The Message Bus
State management without the bloat. A simple, file-based **append-only trace log** (`MESSAGE-BUS.md`) acts as the project's nervous system, allowing agents to communicate, hand off tasks, and sync status without complex infrastructure or databases.

### 🛠️ Unified Runner
One script to rule them all. Whether you're using Claude, Codex, or Gemini, `./run-agent.sh` provides a consistent interface to launch, manage, and monitor them. It handles the messy details of CLI flags, sandboxing overrides, and output capture so you don't have to.

### 💎 MCP Steroid Integration
Built to pair with [MCP Steroid](https://mcp-steroid.jonnyzzz.com). Agents don't just guess; they use **IntelliJ IDE inspections**, compiled builds, and precise code navigation to ensure high-quality, bug-free contributions that pass real engineering standards.

## 3. Taglines
*   "Turn your terminal into a dev shop."
*   "Parallel AI. Zero magic. Full control."
*   "Don't just chat with code. Swarm it."
*   "The operating system for your AI workforce."
*   "Orchestrate. Execute. Ship."

## 4. Why Eugene Built This
Eugene Petrenko (@jonnyzzz) didn't build this to ride the hype train; he built it to solve a real engineering problem. Managing multiple AI sessions manually is chaotic—context gets lost, changes are untraceable, and quality suffers.

He needed a way to scale his own productivity by having multiple agents work on complex tasks simultaneously, but with the rigor of a senior engineer. He wanted a system where he could see *exactly* what prompted an action and *exactly* what the result was. **run-agent.sh** bridges the gap between a fragile "chat" and a robust "runtime," adding the missing layer of coordination and quality control (via IDE integration) that turns LLMs into reliable contributors.

## 5. Target Audience
*   **Senior Developers & Architects:** Who want to automate complex refactoring or feature implementation workflows with precision.
*   **AI Engineers:** Building custom agentic workflows who need a solid, traceable foundation.
*   **Platform Teams:** Looking to integrate LLM capabilities into their CI/CD or internal developer platforms without locking into a proprietary SaaS.

## 6. Call to Action
Stop micro-managing your AI.
**Clone the repo, read `THE_PROMPT_v5.md`, and unleash your swarm today.**

[View on GitHub](https://github.com/jonnyzzz/run-agent)
