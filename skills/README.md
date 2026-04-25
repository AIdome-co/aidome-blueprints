# Agent Skills

This directory contains [Agent Skills](https://agentskills.io/specification) — self-contained folders an AI agent can load to specialize for a task.

Skills are consumable by:

- **Claude Code** (auto-discovered)
- **GitHub Copilot CLI** (`gh copilot skill install ./skills/<name>` — future)
- **OpenAI Codex CLI** (read `SKILL.md` directly)
- Any agent that implements the Agent Skills spec

## Available skills

| Skill | Purpose | Use when |
|-------|---------|----------|
| [`planning-with-files`](./planning-with-files/) | Manus-style persistent markdown planning (`task_plan.md`, `findings.md`, `progress.md`) | Any task spanning 3+ phases or 5+ tool calls — e.g., authoring a new blueprint, cross-cutting refactors, customer migrations |

## Attribution

- `planning-with-files` is imported from [OthmanAdi/planning-with-files](https://github.com/OthmanAdi/planning-with-files) under the MIT License. Only `SKILL.md` and `templates/` are vendored; hook scripts and multi-language variants are not copied.
