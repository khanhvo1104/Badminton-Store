# Codex × Cursor automation

This repository uses Codex as technical lead and Cursor Agent as the implementation developer. GitHub Actions is the final quality gate.

## Safety model

- One task per branch and pull request.
- The controller requires a clean worktree before starting.
- Cursor owns commits, pushes, and the pull request on the controller-created
  task branch. It cannot change branches/remotes, push to `develop`, or merge.
- Codex planning and review run read-only with structured JSON output.
- Cursor runs local quality gates and publishes their real results in the PR.
- Codex reviews the PR, comments requested changes, asks Cursor to update the
  same branch, and performs the final merge only after approval.
- Auto-merge is disabled by default. Enable it only after the workflow has completed several safe tasks successfully.

## Prerequisites

- Authenticated Cursor Agent CLI at `~/.local/bin/agent`.
- Authenticated Codex CLI.
- Authenticated GitHub CLI with access to this repository.
- A separate Cursor GitHub CLI config and SSH key. The controller injects
  these only into the Cursor subprocess, so Cursor publishes as its developer
  account while Codex keeps the technical-lead account.
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
4. Ask Cursor Agent to implement the plan and run the required gates.
5. Ask Cursor to commit, push the task branch, and open a PR into `develop`.
6. Enforce allowed paths, protected-branch rules, and secret policies.
7. Ask Codex for a structured read-only PR review.
8. Post blocking findings as file-level GitHub review threads.
9. Ask Cursor to update the same branch; after it commits and pushes, the
   controller replies in each thread using the Cursor developer account.
10. Codex reviews only the incremental fix. When it approves, the controller
    resolves the addressed threads, waits for GitHub checks, and merges into
    `develop`.

Run artifacts are written under `.automation/runs/` and ignored by Git.

## Token-efficient reviews

The first Codex review receives the complete task diff with a small amount of
surrounding context. If changes are requested, later reviews receive only the
commits added since the previous review plus the prior blocking findings.
Unchanged files are not re-audited; repository-wide path and secret checks
still run on every attempt.

Cursor's complete stream-json transcript is retained under `.automation/runs/`
for diagnostics. The controller prints only short assistant updates so file
contents, tool traces, and test logs do not inflate the parent Codex context.

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
