#!/usr/bin/env python3
"""Safe local orchestrator for Codex planning/review and Cursor implementation."""

from __future__ import annotations

import argparse
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
AUTOMATION = ROOT / ".automation"
CONFIG_PATH = AUTOMATION / "config.json"
TASK_ID_RE = re.compile(r"\b(TASK-\d+)\b", re.IGNORECASE)
SECRET_PATTERNS = (
    re.compile(r"(?i)(service[_-]?role|secret[_-]?key)\s*[:=]\s*[^\s]+"),
    re.compile(r"(?i)-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    re.compile(r"\bgh[oprsu]_[A-Za-z0-9_]{20,}\b"),
)


class AutomationError(RuntimeError):
    pass


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def activate_tool_paths(config: dict) -> None:
    paths = [str(Path(config["flutter_sdk"]).expanduser() / "bin")]
    paths.append(str(Path(config["cursor_agent"]).expanduser().parent))
    os.environ["PATH"] = os.pathsep.join(paths + [os.environ.get("PATH", "")])


def run(
    command: list[str] | str,
    *,
    check: bool = True,
    capture: bool = False,
    input_text: str | None = None,
) -> subprocess.CompletedProcess[str]:
    shell = isinstance(command, str)
    printable = command if shell else " ".join(shlex.quote(part) for part in command)
    print(f"+ {printable}", flush=True)
    result = subprocess.run(
        command,
        cwd=ROOT,
        shell=shell,
        text=True,
        input=input_text,
        capture_output=capture,
        env={**os.environ, "NO_COLOR": "1"},
    )
    if capture and result.stdout:
        print(result.stdout, end="")
    if check and result.returncode != 0:
        if capture and result.stderr:
            print(result.stderr, file=sys.stderr, end="")
        raise AutomationError(f"Command failed ({result.returncode}): {printable}")
    return result


def git(*args: str, capture: bool = True, check: bool = True) -> str:
    result = run(["git", *args], capture=capture, check=check)
    return result.stdout.strip() if capture else ""


def command_exists(command: str) -> bool:
    path = Path(command).expanduser()
    return path.is_file() if path.is_absolute() else shutil.which(command) is not None


def task_identity(task_path: Path) -> tuple[str, str]:
    text = task_path.read_text(encoding="utf-8")
    match = TASK_ID_RE.search(text) or TASK_ID_RE.search(task_path.name)
    if not match:
        raise AutomationError("Task must contain an ID such as TASK-001")
    task_id = match.group(1).upper()
    slug = re.sub(r"[^a-z0-9]+", "-", task_path.stem.lower()).strip("-")
    return task_id, slug


def allowed_paths(task_text: str) -> list[str]:
    match = re.search(
        r"(?ms)^## Allowed paths\s*$\n(.*?)(?=^##\s|\Z)", task_text
    )
    if not match:
        raise AutomationError("Task is missing an '## Allowed paths' section")
    paths = []
    for line in match.group(1).splitlines():
        item = line.strip()
        if item.startswith("-"):
            paths.append(item[1:].strip().strip("`"))
    if not paths:
        raise AutomationError("Task must list at least one allowed path")
    return paths


def path_is_allowed(path: str, allowed: list[str]) -> bool:
    normalized = path.rstrip("/")
    return any(
        normalized == item.rstrip("/")
        or normalized.startswith(item.rstrip("/") + "/")
        for item in allowed
    )


def changed_paths(base: str = "HEAD") -> list[str]:
    output = git("diff", "--name-only", base)
    untracked = git("ls-files", "--others", "--exclude-standard")
    return sorted({p for p in (output + "\n" + untracked).splitlines() if p})


def policy_check(config: dict | None = None, allowed: list[str] | None = None) -> None:
    config = config or load_json(CONFIG_PATH)
    paths = changed_paths()
    protected = [p.rstrip("/") for p in config["protected_paths"]]
    violations: list[str] = []
    for path in paths:
        if any(path == item or path.startswith(item + "/") for item in protected):
            violations.append(f"protected path changed: {path}")
        if allowed is not None and not path_is_allowed(path, allowed):
            violations.append(f"path outside task scope: {path}")
        file_path = ROOT / path
        if file_path.is_file() and file_path.stat().st_size <= 2_000_000:
            try:
                content = file_path.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                continue
            for pattern in SECRET_PATTERNS:
                if pattern.search(content):
                    violations.append(f"possible secret in: {path}")
                    break
    staged = git("diff", "--cached", "--name-only")
    if staged:
        violations.append("index is not clean; the controller stages only after approval")
    if violations:
        raise AutomationError("Policy violations:\n- " + "\n- ".join(violations))
    print("Automation policy check passed.")


def doctor() -> None:
    config = load_json(CONFIG_PATH)
    checks = {
        "git": command_exists("git"),
        "python3": command_exists("python3"),
        "gh": command_exists("gh"),
        "codex": command_exists(config["codex_cli"]),
        "cursor-agent": command_exists(config["cursor_agent"]),
        "dart": command_exists("dart"),
        "flutter": command_exists("flutter"),
        "supabase": command_exists("supabase"),
    }
    for name, ok in checks.items():
        print(f"{'OK' if ok else 'MISSING':7} {name}")
    run([config["cursor_agent"], "status"], check=False)
    run([config["codex_cli"], "login", "status"], check=False)
    run(["gh", "auth", "status"], check=False)
    if not all(checks.values()):
        raise AutomationError("Doctor found missing required tools")


def invoke_codex(
    config: dict, prompt: str, schema: Path, output: Path
) -> dict:
    run(
        [
            config["codex_cli"],
            "exec",
            "--ephemeral",
            "--sandbox",
            "read-only",
            "--cd",
            str(ROOT),
            "--output-schema",
            str(schema),
            "--output-last-message",
            str(output),
            "-",
        ],
        input_text=prompt,
    )
    return load_json(output)


def invoke_cursor(config: dict, prompt: str, log_path: Path) -> None:
    command = [
        config["cursor_agent"],
        "--print",
        "--output-format",
        "stream-json",
        "--sandbox",
        "enabled",
        "--force",
        "--trust",
        "--workspace",
        str(ROOT),
    ]
    if config.get("cursor_model"):
        command.extend(["--model", config["cursor_model"]])
    command.append(prompt)
    print("+ " + " ".join(shlex.quote(part) for part in command[:-1]) + " <prompt>")
    with log_path.open("w", encoding="utf-8") as log:
        process = subprocess.Popen(
            command,
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            env={**os.environ, "NO_COLOR": "1"},
        )
        assert process.stdout is not None
        for line in process.stdout:
            print(line, end="")
            log.write(line)
        if process.wait() != 0:
            raise AutomationError("Cursor Agent failed; see run log")


def quality_gates(config: dict, touches_supabase: bool) -> tuple[bool, str]:
    commands = list(config["quality_commands"])
    if touches_supabase:
        commands.extend(config["supabase_quality_commands"])
    results = []
    passed = True
    for command in commands:
        result = run(command, capture=True, check=False)
        results.append(f"$ {command}\nexit={result.returncode}\n{result.stdout}\n{result.stderr}")
        if result.returncode != 0:
            passed = False
            break
    return passed, "\n\n".join(results)


def ensure_clean_start(config: dict) -> None:
    status = git("status", "--porcelain")
    if status:
        raise AutomationError("Worktree must be clean before automation starts")
    branch = git("branch", "--show-current")
    if branch != config["base_branch"]:
        raise AutomationError(
            f"Start from {config['base_branch']!r}; current branch is {branch!r}"
        )


def create_pull_request(config: dict, task_id: str, title: str) -> None:
    body = (
        f"Automated implementation for `{task_id}`.\n\n"
        "- Planned and reviewed by Codex\n"
        "- Implemented by Cursor Agent\n"
        "- Local quality gates passed\n\n"
        "This PR remains subject to GitHub Actions and branch protection."
    )
    result = run(
        [
            "gh", "pr", "create", "--draft", "--base", config["base_branch"],
            "--title", title, "--body", body,
        ],
        capture=True,
    )
    pr_url = result.stdout.strip().splitlines()[-1]
    print(f"Pull request: {pr_url}")
    if config.get("auto_merge"):
        run(["gh", "pr", "ready", pr_url])
        run(["gh", "pr", "merge", "--auto", "--squash", pr_url])


def run_task(task_path: Path) -> None:
    config = load_json(CONFIG_PATH)
    task_path = task_path.resolve()
    if not task_path.is_relative_to(AUTOMATION / "tasks"):
        raise AutomationError("Task file must be under .automation/tasks")
    ensure_clean_start(config)
    task_text = task_path.read_text(encoding="utf-8")
    task_id, slug = task_identity(task_path)
    allowed = allowed_paths(task_text)
    branch = config["branch_prefix"] + slug
    run_dir = AUTOMATION / "runs" / (
        datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "-" + task_id.lower()
    )
    run_dir.mkdir(parents=True)

    git("switch", "-c", branch, capture=False)
    protected_head = git("rev-parse", "HEAD")
    protected_remote = git("remote", "get-url", config["remote"])
    planner_prompt = (
        (AUTOMATION / "prompts/codex_planner.md").read_text(encoding="utf-8")
        + "\n\nACTIVE TASK:\n"
        + task_text
    )
    plan_path = run_dir / "plan.json"
    plan = invoke_codex(
        config, planner_prompt, AUTOMATION / "schemas/plan.schema.json", plan_path
    )
    if plan["status"] != "ready":
        raise AutomationError("Codex planner blocked the task: " + plan["summary"])

    base_cursor_prompt = (
        (AUTOMATION / "prompts/cursor_system.md").read_text(encoding="utf-8")
        + "\n\nACTIVE TASK:\n"
        + task_text
        + "\n\nCODEX PLAN:\n"
        + json.dumps(plan, indent=2)
    )
    feedback = ""
    approved = False
    for attempt in range(config["max_fix_attempts"] + 1):
        cursor_prompt = base_cursor_prompt
        if feedback:
            cursor_prompt += (
                "\n\nVALIDATION FEEDBACK FROM THE PREVIOUS ATTEMPT:\n"
                + feedback
                + "\nFix only these issues, then rerun the relevant checks."
            )
        invoke_cursor(config, cursor_prompt, run_dir / f"cursor-attempt-{attempt + 1}.jsonl")

        if git("branch", "--show-current") != branch:
            raise AutomationError("Cursor changed the active Git branch")
        if git("rev-parse", "HEAD") != protected_head:
            raise AutomationError("Cursor created or changed a Git commit")
        if git("remote", "get-url", config["remote"]) != protected_remote:
            raise AutomationError("Cursor changed the Git remote")
        policy_check(config, allowed)
        paths = changed_paths()
        if not paths:
            raise AutomationError("Cursor completed without producing a change")

        quality_passed, quality = quality_gates(
            config, any(p.startswith("supabase/") for p in paths)
        )
        (run_dir / f"quality-attempt-{attempt + 1}.txt").write_text(
            quality, encoding="utf-8"
        )
        if not quality_passed:
            feedback = "One or more quality gates failed:\n\n" + quality
            continue

        diff = git("diff", "--no-ext-diff", "--unified=80")
        review_prompt = (
            (AUTOMATION / "prompts/codex_reviewer.md").read_text(encoding="utf-8")
            + "\n\nACTIVE TASK:\n" + task_text
            + "\n\nPLAN:\n" + json.dumps(plan, indent=2)
            + "\n\nQUALITY GATES:\n" + quality
            + "\n\nDIFF:\n" + diff
        )
        review_path = run_dir / f"review-attempt-{attempt + 1}.json"
        review = invoke_codex(
            config, review_prompt, AUTOMATION / "schemas/review.schema.json", review_path
        )
        if review["verdict"] == "approve":
            approved = True
            break
        feedback = "Codex review requested changes:\n- " + "\n- ".join(
            review["blocking_findings"]
        )

    if not approved:
        raise AutomationError(
            f"Task did not pass after {config['max_fix_attempts'] + 1} attempts"
        )

    policy_check(config, allowed)
    run(["git", "add", "--", *paths])
    staged = git("diff", "--cached", "--name-only")
    if set(staged.splitlines()) != set(paths):
        raise AutomationError("Staged file set differs from reviewed file set")
    run(["git", "commit", "-m", f"{task_id}: {plan['summary'][:60]}"])
    if config.get("auto_push"):
        run(["git", "push", "-u", config["remote"], branch])
    if config.get("auto_create_pr"):
        create_pull_request(config, task_id, f"{task_id}: {plan['summary']}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("doctor")
    subparsers.add_parser("policy-check")
    run_parser = subparsers.add_parser("run")
    run_parser.add_argument("task", type=Path)
    args = parser.parse_args()
    activate_tool_paths(load_json(CONFIG_PATH))
    try:
        if args.command == "doctor":
            doctor()
        elif args.command == "policy-check":
            policy_check()
        elif args.command == "run":
            run_task(args.task)
    except (AutomationError, OSError, subprocess.SubprocessError, json.JSONDecodeError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
