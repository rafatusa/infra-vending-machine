#!/usr/bin/env python3
"""
Open or update a vend/* PR with the terraform plan output.
All inputs come from environment variables — no YAML escaping needed.
Writes PR_NUM=<number> to $GITHUB_OUTPUT.
"""
import os
import subprocess
import sys


def run(cmd, capture=False):
    result = subprocess.run(cmd, capture_output=capture, text=True)
    if result.returncode != 0:
        print(f"ERROR running: {' '.join(cmd)}\n{result.stderr}", file=sys.stderr)
        sys.exit(result.returncode)
    return result.stdout.strip() if capture else None


def main():
    repo        = os.environ["GITHUB_REPOSITORY"]
    issue_num   = os.environ["ISSUE_NUM"]
    name        = os.environ["REQUEST_NAME"]
    action      = os.environ["UDAP_ACTION"]
    branch      = os.environ["BRANCH"]
    plan_exit   = os.environ.get("PLAN_EXIT", "1")
    resource    = os.environ.get("RESOURCE_TYPE", "")
    account     = os.environ.get("ACCOUNT", "")
    environment = os.environ.get("ENVIRONMENT", "")

    plan = "(plan not available)"
    try:
        with open("/tmp/tf-plan.txt") as f:
            plan = f.read()[-30000:]
    except FileNotFoundError:
        pass

    status_label = "PASS" if plan_exit == "0" else "FAIL"

    body = "\n".join([
        f"Resolves #{issue_num}",
        "",
        f"Action: {action}",
        f"Resource: {resource}",
        f"Account: {account}",
        f"Environment: {environment}",
        "",
        f"### Terraform Plan [{status_label}]",
        "```",
        plan,
        "```",
    ])

    with open("/tmp/pr-body.txt", "w") as f:
        f.write(body)

    # Check for an existing open PR from this branch
    existing = run(
        ["gh", "pr", "list", "--repo", repo, "--head", branch,
         "--state", "open", "--json", "number", "--jq", ".[0].number // empty"],
        capture=True,
    )

    if not existing:
        pr_url = run(
            ["gh", "pr", "create", "--repo", repo,
             "--title", f"[VEND] {name} #{issue_num}",
             "--head", branch, "--base", "main",
             "--body-file", "/tmp/pr-body.txt"],
            capture=True,
        )
        pr_num = pr_url.rstrip("/").split("/")[-1]
    else:
        pr_num = existing
        run(["gh", "pr", "edit", pr_num, "--repo", repo,
             "--body-file", "/tmp/pr-body.txt"])

    # Comment on the issue
    if status_label == "PASS":
        comment = f"Request received. Action: {action}\n\nPlan clean — PR #{pr_num} is ready for review."
    else:
        comment = f"Request received. Action: {action}\n\nPlan FAILED — check PR #{pr_num} for details."

    run(["gh", "issue", "comment", issue_num, "--repo", repo, "--body", comment])

    # Emit for GITHUB_OUTPUT
    github_output = os.environ.get("GITHUB_OUTPUT", "")
    if github_output:
        with open(github_output, "a") as f:
            f.write(f"PR_NUM={pr_num}\n")
    else:
        print(f"PR_NUM={pr_num}")


if __name__ == "__main__":
    main()
