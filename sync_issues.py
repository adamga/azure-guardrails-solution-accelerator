import os
from github import Github
import requests

# === CONFIGURATION ===
GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")  # Or hardcode for testing
UPSTREAM_REPO = "ssc-spc-ccoe-cei/azure-guardrails-solution-accelerator"
FORK_REPO = "adamga/azure-guardrails-solution-accelerator"
LABEL_PREFIX = "[Upstream]"

# === INIT ===
gh = Github(GITHUB_TOKEN)
upstream = gh.get_repo(UPSTREAM_REPO)
fork = gh.get_repo(FORK_REPO)

# === FETCH ISSUES FROM UPSTREAM ===
upstream_issues = upstream.get_issues(state="open")

# === SYNC TO FORK ===
for issue in upstream_issues:
    # Check if issue already exists in fork (by title or custom label)
    existing = fork.get_issues(state="all", labels=[LABEL_PREFIX])
    if any(i.title == issue.title for i in existing):
        continue  # Skip if already synced

    # Create issue in fork
    # Check if triage label exists and prepare labels list
    available_labels = [l.name for l in fork.get_labels()]
    labels_to_apply = []
    if "triage" in available_labels:
        labels_to_apply.append("triage")
    
    fork.create_issue(
        title=f"{LABEL_PREFIX} {issue.title}",
        body=f"**Original Issue:** {issue.html_url}\n\n{issue.body}",
        labels=labels_to_apply
    )

print("Issues synced successfully.")
