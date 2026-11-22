---
name: repo-launcher
description: Create a brand-new GitHub repo and publish code to it end-to-end, even when the session has no repo-creation permission. Use when the user says "make a repo", "new repo", "publish this code", or "push this to GitHub".
---

# Repo Launcher

Creates a new GitHub repository and ships code into it in one flow:
**check access → create repo → attach → build → commit & push → verify**.

Why this exists: in Claude sessions, GitHub access is often scoped to *existing*
repos, and the `gh` CLI token may be missing or invalid — so "create a repo"
fails. This skill routes around that by creating the repo through the user's
own signed-in Chrome, then pushing through the session's normal git access.

---

## Step 0 — Gather inputs (ask only what's missing)

| Input | Default if user says "you pick" |
|---|---|
| Repo name | Short, kebab-case, describes the project (`claude-repo-launcher`, `issue-lens`, `core-os-dashboard`) |
| Description | One line, under ~100 chars, what it does |
| Visibility | Match the user's existing repos (check `list_repos`); if mixed, ask |
| Starting files | **None** — leave README/.gitignore/license off so the first push is clean |
| Content | What code/files go in the first commit |

Naming rules: lowercase, hyphens, no spaces, no trailing dashes/typos, not
already taken (GitHub shows "✓ name is available" under the field).

---

## Step 1 — Check access (fastest route first)

Run:

```bash
gh auth status 2>&1 | head -5
```

- **Signed in** → create with the CLI and skip Step 2:
  ```bash
  gh repo create OWNER/NAME --public --description "..."   # or --private
  ```
- **Not signed in / "token is invalid"** → use the browser route (Step 2).
  Do not try to log `gh` in with the user's password or a token — that is
  credential handling and is off-limits.

---

## Step 2 — Create the repo in the user's Chrome

1. Load the Claude in Chrome tools in ONE ToolSearch call
   (`tabs_context_mcp, navigate, computer, find, read_page, tabs_create_mcp, tabs_close_mcp`).
   Read the `chrome-browser` skill first if it is listed.
2. `tabs_context_mcp` → open a new tab (don't hijack the user's tabs).
3. Navigate to `https://github.com/new`.
   - Screenshot: avatar in the top-right = signed in.
   - If a login page shows, **stop** and ask the user to sign in themselves.
4. `find` the fields: "Repository name", "Description", "Choose visibility",
   "Create repository".
5. Fill the name and description. Prefer `form_input` (sets the value exactly)
   over click + `type` (can drop characters).
6. Set visibility (Public is GitHub's current default — verify in screenshot).
7. Leave README / .gitignore / license **off**.
8. **Verify before submitting** — take a screenshot and `zoom` on the name and
   description. Typing can drop characters (seen in testing: "publishes" became
   "publishs"). Fix any typo now; it's annoying to fix later.
9. **Confirm with the user** — show owner/name, description, visibility, and ask
   "Create it?". Creating a public repo publishes something under their name, so
   it needs a clear yes (unless their message already said "create it").
10. Click **Create repository**. Success = URL becomes
    `github.com/OWNER/NAME` and the "Quick setup" page shows.
11. Close the tab you opened when you're done.

---

## Step 3 — Attach the repo to the session

```
add_repo(owner=OWNER, repo=NAME, access="push")
```

Then clone exactly once into the working directory, with a long timeout (≈10 min):

```bash
git clone --depth 1 https://github.com/OWNER/NAME ./NAME
```

"You appear to have cloned an empty repository" is expected. If the
`register_repo_root` tool exists, call it with the clone's absolute path.

**Local Claude Code / your own machine:** `add_repo` isn't needed — your own git
credentials already have push access to repos you own. Just clone and continue.

If `add_repo` returns an authorization error, relay its exact reason and point
the user to claude.ai **Settings → Connectors** to reconnect GitHub. Don't retry.

---

## Step 4 — Build the content

Write the project files in the clone. A complete first commit usually has:

- `README.md` — what it is, why, how to use, project structure
- The actual code / skill / content
- `.gitignore` if the stack needs one (Python: `__pycache__/`, `.venv/`, `.env`;
  Node: `node_modules/`, `.env`, `dist/`)
- **Never** commit secrets: `.env`, tokens, `credentials.json`, API keys.
- Ask before adding a LICENSE — license choice is the owner's call.

---

## Step 5 — Commit & push

```bash
cd NAME
git add -A
git commit -m "Initial commit: <what this is>"
git -c push.negotiate=true push -u origin main
```

A `push negotiation failed` warning does not mean the push failed — check the
final lines for `main -> main`.

If the session supplies commit attribution lines, append them to the message.

---

## Step 6 — Verify & hand off

1. `git log --oneline -1` and `git ls-remote origin` → remote has the commit.
2. Optionally reload `github.com/OWNER/NAME` in Chrome and screenshot the file list.
3. Polish (optional): click the ⚙ next to **About** on the repo page to fix the
   description and add 4–6 topics (e.g. `claude`, `automation`) for discoverability.
   Set the description with `form_input`, type topics separated by spaces, then
   **Save changes** and screenshot to confirm the dialog closed.
4. Report to the user in 2–3 lines: repo link, what's in it, one next step.

---

## Failure playbook

| Symptom | Fix |
|---|---|
| `gh` token invalid | Use Chrome route (Step 2) |
| Chrome tools missing / extension not responding | Tell the user; fallback = user creates the empty repo at github.com/new, then continue from Step 3 |
| GitHub login page in Chrome | User signs in themselves — never type passwords |
| "Name already exists" | Suggest 2–3 alternatives, or push into the existing repo if it's theirs and empty |
| `add_repo` auth/policy error | Relay exact reason; reconnect GitHub in Settings → Connectors |
| Clone 429 | Sleep 5s, retry once — it's a local concurrency cap |
| Push 413 / rejected | `git fetch --depth=50 origin main`, rebase, push again |
| Browser actions fail 2–3 times | Stop and ask the user — don't loop |

## Safety rules

- Confirm before clicking **Create** (publishes under the user's name).
- Never enter passwords, tokens, or 2FA codes; never commit secrets.
- Only create repos under the user's own account unless they name an org.
- Never delete or overwrite an existing repo as part of this flow.
