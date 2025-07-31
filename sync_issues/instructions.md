# 🧾 Customer Repo Triage Automation Guide

This guide helps you:

- Fork a customer repo you can’t modify
- Sync code and issues regularly
- Use GitHub Copilot to triage and suggest fixes
- Automate everything with GitHub Actions

---

## 📌 Overview

| Task | Tool |
|------|------|
| Fork customer repo | GitHub |
| Sync code | GitHub Actions |
| Sync issues | Python + GitHub API |
| Triage issues | GitHub Copilot |
| Automate everything | GitHub Actions |

---

## ✅ Step 1: Fork the Customer Repository

1. Go to the customer’s GitHub repository.
2. Click **Fork** and choose your GitHub Enterprise (GHE) account or organization.
3. This creates a forked repo under your control (e.g., `your-org/customer-repo-fork`).

---

## 🔐 Step 2: Create a GitHub Personal Access Token (PAT)

1. Go to GitHub Developer Settings.
2. Click **"Generate new token (classic)"**.
3. Select scopes:
   - `repo` (full control of private repositories)
   - `workflow` (for GitHub Actions)
4. Copy and save the token securely.

---

## 🧰 Step 3: Set Up Python Environment

### a. Install Python

1. Download the latest Python 3.11+ from python.org.
2. Run the installer:
   - ✅ Check **“Add Python to PATH”**
   - Click **Customize installation**
   - Ensure **pip** is selected
   - Click **Install**

### b. Verify Installation

Open Command Prompt and run:

```bash
python --version
pip --version
