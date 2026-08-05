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
import tempfile
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
    env_override: dict[str, str] | None = None,
    print_output: bool = True,
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
        env={**os.environ, "NO_COLOR": "1", **(env_override or {})},
    )
    if capture and print_output and result.stdout:
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


def task_risk(task_text: str) -> str:
    match = re.search(r"(?im)^Risk:\s*(low|medium|high)\s*$", task_text)
    # Missing/unknown risk stays on the conservative planner path.
    return match.group(1).lower() if match else "high"


def section_bullets(task_text: str, heading: str) -> list[str]:
    match = re.search(
        rf"(?ms)^## {re.escape(heading)}\s*$\n(.*?)(?=^##\s|\Z)",
        task_text,
    )
    if not match:
        return []
    return [
        line.strip()[1:].strip().strip("`")
        for line in match.group(1).splitlines()
        if line.strip().startswith("-")
    ]


def task_spec_is_complete(task_text: str) -> bool:
    required_headings = (
        "Objective",
        "Scope",
        "Non-goals",
        "Allowed paths",
        "Acceptance criteria",
        "Required quality gates",
    )
    return all(
        re.search(rf"(?m)^## {re.escape(heading)}\s*$", task_text)
        for heading in required_headings
    )


def task_spec_plan(task_text: str, allowed: list[str], risk: str) -> dict:
    checks = section_bullets(task_text, "Required quality gates")
    return {
        "status": "ready",
        "summary": (
            f"Use the active {risk}-risk task specification as the implementation "
            "plan; the separate Codex planner was skipped to avoid duplicate "
            "repository analysis."
        ),
        "steps": [
            "Implement every scoped requirement and acceptance criterion exactly.",
            "Modify only the task's allowed paths and preserve all non-goals.",
            "Run every required quality gate and report truthful results in the PR.",
        ],
        "files": allowed,
        "checks": checks,
        "risks": [
            "Stop and report a blocker if implementation requires work outside the task scope."
        ],
    }


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


def policy_check(
    config: dict | None = None,
    allowed: list[str] | None = None,
    base: str = "HEAD",
) -> None:
    config = config or load_json(CONFIG_PATH)
    paths = changed_paths(base)
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
    config: dict,
    prompt: str,
    schema: Path,
    output: Path,
    transcript: Path,
    *,
    isolated: bool = False,
) -> dict:
    with tempfile.TemporaryDirectory(prefix="badminton-codex-review-") as temp_dir:
        working_dir = temp_dir if isolated else str(ROOT)
        command = [
            config["codex_cli"],
            "exec",
            "--ephemeral",
            "--sandbox",
            "read-only",
            "--cd",
            working_dir,
        ]
        if isolated:
            command.append("--skip-git-repo-check")
        command.extend(
            [
                "--output-schema",
                str(schema),
                "--output-last-message",
                str(output),
                "-",
            ]
        )
        result = run(
            command,
            input_text=prompt,
            capture=True,
            check=False,
            print_output=False,
        )
    full_transcript = result.stdout + result.stderr
    transcript.write_text(full_transcript, encoding="utf-8")
    if result.returncode != 0:
        raise AutomationError(
            f"Codex failed ({result.returncode}); see {transcript.relative_to(ROOT)}"
        )
    response = load_json(output)
    token_matches = re.findall(
        r"tokens used\s*[\r\n]+\s*([0-9,]+)", full_transcript, re.IGNORECASE
    )
    tokens = token_matches[-1] if token_matches else "unknown"
    kind = "review" if "verdict" in response else "plan"
    state = response.get("verdict", response.get("status", "complete"))
    summary = " ".join(response.get("summary", "").split())
    if len(summary) > 500:
        summary = summary[:497] + "..."
    print(f"Codex {kind}: {state} (tokens={tokens}) — {summary}", flush=True)
    for finding in response.get("blocking_findings", []):
        print(
            f"Codex finding: {finding['path']} — {finding['title']}",
            flush=True,
        )
    return response


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
    cursor_env = {**os.environ, "NO_COLOR": "1"}
    cursor_env.update(
        {
            "GH_CONFIG_DIR": str(Path(config["cursor_gh_config_dir"]).expanduser()),
            "GIT_SSH_COMMAND": (
                "ssh -F /dev/null -o IdentitiesOnly=yes -i "
                + str(Path(config["cursor_ssh_key"]).expanduser())
            ),
            "GIT_AUTHOR_NAME": config["cursor_git_name"],
            "GIT_AUTHOR_EMAIL": config["cursor_git_email"],
            "GIT_COMMITTER_NAME": config["cursor_git_name"],
            "GIT_COMMITTER_EMAIL": config["cursor_git_email"],
        }
    )
    with log_path.open("w", encoding="utf-8") as log:
        process = subprocess.Popen(
            command,
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            env=cursor_env,
        )
        assert process.stdout is not None
        for line in process.stdout:
            log.write(line)
            # Cursor's stream-json output contains thoughts, full file contents,
            # diffs, and command output. Persist that detail for diagnostics but
            # keep the controller console small so it does not become Codex
            # conversation context. Only surface short developer-facing updates.
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue
            if event.get("type") != "assistant":
                continue
            content = event.get("message", {}).get("content", [])
            messages = [
                item.get("text", "").strip()
                for item in content
                if item.get("type") == "text" and item.get("text", "").strip()
            ]
            if messages:
                update = " ".join(messages)
                if len(update) > 800:
                    update = update[:797] + "..."
                print(f"Cursor: {update}", flush=True)
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


def current_pull_request(branch: str) -> str:
    result = run(
        ["gh", "pr", "view", branch, "--json", "url", "--jq", ".url"],
        capture=True,
        check=False,
    )
    if result.returncode != 0 or not result.stdout.strip():
        raise AutomationError(
            "Cursor must push the task branch and open a PR targeting develop"
        )
    return result.stdout.strip().splitlines()[-1]


def pull_request_context(pr_url: str) -> tuple[str, int, str]:
    repo = run(
        ["gh", "repo", "view", "--json", "nameWithOwner", "--jq", ".nameWithOwner"],
        capture=True,
        print_output=False,
    ).stdout.strip()
    details = load_json_from_output(
        run(
            ["gh", "pr", "view", pr_url, "--json", "number,headRefOid"],
            capture=True,
            print_output=False,
        ).stdout
    )
    return repo, int(details["number"]), details["headRefOid"]


def load_json_from_output(output: str) -> dict:
    lines = [line for line in output.splitlines() if line.strip()]
    if not lines:
        raise AutomationError("Expected JSON command output")
    return json.loads(lines[-1])


def post_review_feedback(pr_url: str, findings: list[dict]) -> list[int]:
    repo, number, head_oid = pull_request_context(pr_url)
    comment_ids: list[int] = []
    for finding in findings:
        body = (
            f"**Codex review — {finding['title']}**\n\n"
            f"{finding['body']}"
        )
        response = load_json_from_output(
            run(
                [
                    "gh", "api", "--method", "POST",
                    f"repos/{repo}/pulls/{number}/comments",
                    "-f", f"body={body}",
                    "-f", f"commit_id={head_oid}",
                    "-f", f"path={finding['path']}",
                    "-f", "subject_type=file",
                ],
                capture=True,
                print_output=False,
            ).stdout
        )
        comment_ids.append(int(response["id"]))
    return comment_ids


def cursor_github_env(config: dict) -> dict[str, str]:
    return {
        "GH_CONFIG_DIR": str(Path(config["cursor_gh_config_dir"]).expanduser()),
        "GIT_SSH_COMMAND": (
            "ssh -F /dev/null -o IdentitiesOnly=yes -i "
            + str(Path(config["cursor_ssh_key"]).expanduser())
        ),
    }


def reply_to_review_threads(
    config: dict,
    pr_url: str,
    comment_ids: list[int],
    commit_sha: str,
) -> None:
    if not comment_ids:
        return
    repo, number, _ = pull_request_context(pr_url)
    short_sha = commit_sha[:7]
    for comment_id in comment_ids:
        body = (
            "**Cursor Agent update**\n\n"
            f"Đã cập nhật theo review trong commit `{short_sha}`, push lên cùng "
            "task branch và cập nhật kết quả kiểm tra trong PR. Sẵn sàng để "
            "Codex review lại."
        )
        run(
            [
                "gh", "api", "--method", "POST",
                f"repos/{repo}/pulls/{number}/comments/{comment_id}/replies",
                "-f", f"body={body}",
            ],
            capture=True,
            env_override=cursor_github_env(config),
            print_output=False,
        )


def resolve_review_threads(pr_url: str, comment_ids: list[int]) -> None:
    if not comment_ids:
        return
    repo, number, _ = pull_request_context(pr_url)
    owner, name = repo.split("/", 1)
    query = """
query($owner:String!,$name:String!,$number:Int!){
  repository(owner:$owner,name:$name){
    pullRequest(number:$number){
      reviewThreads(first:100){
        nodes{id isResolved comments(first:100){nodes{databaseId}}}
      }
    }
  }
}
"""
    response = load_json_from_output(
        run(
            [
                "gh", "api", "graphql",
                "-f", f"query={query}",
                "-f", f"owner={owner}",
                "-f", f"name={name}",
                "-F", f"number={number}",
            ],
            capture=True,
            print_output=False,
        ).stdout
    )
    wanted = set(comment_ids)
    nodes = response["data"]["repository"]["pullRequest"]["reviewThreads"]["nodes"]
    thread_ids = [
        node["id"]
        for node in nodes
        if not node["isResolved"]
        and any(comment["databaseId"] in wanted for comment in node["comments"]["nodes"])
    ]
    mutation = """
mutation($threadId:ID!){
  resolveReviewThread(input:{threadId:$threadId}){thread{isResolved}}
}
"""
    for thread_id in thread_ids:
        run(
            [
                "gh", "api", "graphql",
                "-f", f"query={mutation}",
                "-f", f"threadId={thread_id}",
            ],
            capture=True,
            print_output=False,
        )


def run_task(task_path: Path) -> None:
    config = load_json(CONFIG_PATH)
    task_path = task_path.resolve()
    if not task_path.is_relative_to(AUTOMATION / "tasks"):
        raise AutomationError("Task file must be under .automation/tasks")
    ensure_clean_start(config)
    task_text = task_path.read_text(encoding="utf-8")
    task_id, slug = task_identity(task_path)
    allowed = allowed_paths(task_text)
    risk = task_risk(task_text)
    branch = config["branch_prefix"] + slug
    run_dir = AUTOMATION / "runs" / (
        datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "-" + task_id.lower()
    )
    run_dir.mkdir(parents=True)

    git("switch", "-c", branch, capture=False)
    protected_head = git("rev-parse", "HEAD")
    protected_remote = git("remote", "get-url", config["remote"])
    plan_path = run_dir / "plan.json"
    planner_risks = {
        str(item).lower() for item in config.get("codex_planner_risks", ["high"])
    }
    needs_planner = risk in planner_risks or not task_spec_is_complete(task_text)
    if needs_planner:
        planner_prompt = (
            (AUTOMATION / "prompts/codex_planner.md").read_text(encoding="utf-8")
            + "\n\nACTIVE TASK:\n"
            + task_text
        )
        plan = invoke_codex(
            config,
            planner_prompt,
            AUTOMATION / "schemas/plan.schema.json",
            plan_path,
            run_dir / "codex-plan.log",
        )
    else:
        plan = task_spec_plan(task_text, allowed, risk)
        plan_path.write_text(json.dumps(plan, indent=2) + "\n", encoding="utf-8")
        print(f"Codex plan: skipped for {risk}-risk task; using task specification")
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
    previous_review: dict | None = None
    reviewed_head = protected_head
    pending_thread_comments: list[int] = []
    all_thread_comments: list[int] = []
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
        if git("remote", "get-url", config["remote"]) != protected_remote:
            raise AutomationError("Cursor changed the Git remote")
        if git("status", "--porcelain"):
            raise AutomationError(
                "Cursor must commit all task changes before requesting review"
            )
        paths = changed_paths(protected_head)
        if not paths:
            raise AutomationError("Cursor completed without producing a change")
        policy_check(config, allowed, protected_head)
        pr_url = current_pull_request(branch)
        pr_base = run(
            ["gh", "pr", "view", pr_url, "--json", "baseRefName", "--jq", ".baseRefName"],
            capture=True,
        ).stdout.strip()
        if pr_base != config["base_branch"]:
            raise AutomationError(
                f"Cursor PR must target {config['base_branch']!r}, got {pr_base!r}"
            )
        quality = run(
            ["gh", "pr", "view", pr_url, "--json", "body", "--jq", ".body"],
            capture=True,
        ).stdout
        current_head = git("rev-parse", "HEAD")
        if attempt > 0 and pending_thread_comments:
            reply_to_review_threads(
                config,
                pr_url,
                pending_thread_comments,
                current_head,
            )
            pending_thread_comments = []
        context_lines = int(config.get("review_diff_context_lines", 5))
        diff = git(
            "diff",
            "--no-ext-diff",
            f"--unified={context_lines}",
            reviewed_head,
            current_head,
        )
        reviewer_rules = (AUTOMATION / "prompts/codex_reviewer.md").read_text(
            encoding="utf-8"
        )
        repository_rules = (ROOT / "AGENTS.md").read_text(encoding="utf-8")
        if attempt == 0:
            review_prompt = (
                reviewer_rules
                + "\n\nREPOSITORY RULES:\n" + repository_rules
                + "\n\nACTIVE TASK:\n" + task_text
                + "\n\nPLAN:\n" + json.dumps(plan, separators=(",", ":"))
                + "\n\nQUALITY GATES:\n" + quality
                + "\n\nTASK DIFF:\n" + diff
            )
        else:
            if not diff.strip():
                raise AutomationError(
                    "Cursor did not commit a change after Codex requested fixes"
                )
            review_prompt = (
                reviewer_rules
                + "\n\nREPOSITORY RULES:\n" + repository_rules
                + "\n\nFOLLOW-UP REVIEW MODE:\n"
                "Review only the incremental diff below and verify that every "
                "previous blocking finding was resolved. Do not re-review "
                "unchanged files or rediscover unrelated findings. Repository-wide "
                "scope and secret checks are enforced separately by the controller."
                + "\n\nPREVIOUS REVIEW:\n"
                + json.dumps(previous_review, separators=(",", ":"))
                + "\n\nQUALITY GATES:\n" + quality
                + "\n\nINCREMENTAL DIFF:\n" + diff
            )
        review_path = run_dir / f"review-attempt-{attempt + 1}.json"
        review = invoke_codex(
            config,
            review_prompt,
            AUTOMATION / "schemas/review.schema.json",
            review_path,
            run_dir / f"codex-review-attempt-{attempt + 1}.log",
            isolated=True,
        )
        if review["verdict"] == "approve":
            approved = True
            break
        new_comments = post_review_feedback(pr_url, review["blocking_findings"])
        pending_thread_comments.extend(new_comments)
        all_thread_comments.extend(new_comments)
        previous_review = review
        reviewed_head = current_head
        feedback = "Codex review requested changes:\n" + "\n".join(
            f"- {finding['path']}: {finding['title']} — {finding['body']}"
            for finding in review["blocking_findings"]
        )

    if not approved:
        raise AutomationError(
            f"Task did not pass after {config['max_fix_attempts'] + 1} attempts"
        )

    policy_check(config, allowed, protected_head)
    pr_url = current_pull_request(branch)
    resolve_review_threads(pr_url, all_thread_comments)
    run(["gh", "pr", "ready", pr_url], check=False)
    run(["gh", "pr", "checks", pr_url, "--watch", "--interval", "10"])
    if config.get("merge_after_codex_approval"):
        run(["gh", "pr", "merge", pr_url, "--merge", "--delete-branch"])
        git("switch", config["base_branch"], capture=False)
        run(["git", "pull", "--ff-only", config["remote"], config["base_branch"]])
    else:
        print(f"Approved pull request: {pr_url}")


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
