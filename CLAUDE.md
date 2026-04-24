# CLAUDE.md

This file is the entry point for **Claude Code** when it opens the `aidome-blueprints` repository.

All guidance for AI coding agents — including Claude Code, GitHub Copilot, and OpenAI Codex — is maintained in a single canonical file to keep behaviour consistent across tools.

👉 **Read [`AGENTS.md`](AGENTS.md) next.**

@AGENTS.md

## Claude-specific notes

- **Skills:** [`skills/planning-with-files/SKILL.md`](skills/planning-with-files/SKILL.md) is auto-discovered. Invoke it for any task that spans 3+ phases or 5+ tool calls.
- **Tool permissions:** This is an IaC repository. Treat `terraform apply`, `aws`, `kubectl apply`, `helm install`, and `ansible-playbook` against real targets as destructive — always ask before running them. `plan`, `--check`, `--dry-run`, `validate`, `lint`, and `fmt` are safe.
- **Slash commands:** Reusable prompts live in [`.github/prompts/`](.github/prompts/). You can paste them inline or invoke them as ad-hoc commands.
- **Memory:** If you are instructed to remember a repo-wide convention, append it to `AGENTS.md` so GitHub Copilot and Codex agents benefit too — don't add a Claude-only file.
