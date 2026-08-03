# Codex × Cursor automation

This repository uses Codex as planner/reviewer/publisher and Cursor Agent as the implementation worker. GitHub Actions is the final quality gate.

## Safety model

- One task per branch and pull request.
- The controller requires a clean worktree before starting.
- Cursor cannot own Git operations and is instructed not to access secrets.
- Codex planning and review run read-only with structured JSON output.
- Publishing happens only after local quality gates and an approving Codex review.
- Auto-merge is disabled by default. Enable it only after the workflow has completed several safe tasks successfully.

## Prerequisites

- Authenticated Cursor Agent CLI at `~/.local/bin/agent`.
- Authenticated Codex CLI.
- Authenticated GitHub CLI with access to this repository.
- Flutter and Dart available on `PATH`.
- Supabase CLI for tasks that touch `supabase/`.

Run:

```bash
python3 scripts/automation.py doctor
```

The controller prepends the configured Flutter SDK and Cursor Agent directories to its own `PATH`; it does not modify your shell profile.

## Run a task

Tasks are Markdown specifications under `.automation/tasks/`. Each task must declare `## Allowed paths` and precise acceptance criteria.

```bash
python3 scripts/automation.py run .automation/tasks/TASK-001-audit.md
```

The controller will:

1. Validate the repository and task.
2. Create `automation/<task-slug>` from the configured base branch.
3. Ask Codex for a structured read-only plan.
4. Ask Cursor Agent to implement the plan in its sandbox.
5. Enforce allowed paths and secret policies.
6. Run formatting, analysis, tests, and relevant Supabase checks.
7. Ask Codex for a structured read-only review.
8. Commit, push, and open a draft pull request when approved.

Run artifacts are written under `.automation/runs/` and ignored by Git.

## Backlog

`.automation/backlog.json` is the durable queue. A scheduler may select the first `ready` task and invoke the controller. Initially, run one task manually to validate authentication and tool paths before enabling a scheduler.

## Enabling auto-merge

Keep `auto_merge` false during rollout. Before changing it to true:

- Require the CI workflow on `develop`.
- Protect `develop` from direct pushes.
- Require branches to be up to date.
- Enable auto-merge in repository settings.
- Confirm the GitHub token cannot bypass branch protection.

The controller requests GitHub auto-merge only after local approval; GitHub still waits for required checks.

## Supabase tasks

Tasks involving migrations, Auth, RLS, Storage, checkout, inventory, or payments are high risk. They must explicitly allow the relevant paths and include database/RLS tests. Never expose a service-role or secret key to Flutter or to run logs.
