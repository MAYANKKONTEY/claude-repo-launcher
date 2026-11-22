---
name: repo-launcher
description: Create a brand-new GitHub repo and publish code to it end-to-end, automatically, even without repo-creation permission. Also rescues work when an existing repo can't be fetched or pushed by creating a new repo and storing it there. Use for "make a repo", "new repo", "publish this code", "push this to GitHub", or when a push or clone to an existing repo fails.
---

# Repo Launcher

Source: https://github.com/MAYANKKONTEY/claude-repo-launcher (MIT)

One flow, end to end:
**check access → create repo → attach → build → commit & push → verify**,
plus a **self-healing fallback**: if an existing repo can't be reached, the work
goes into a fresh repo instead of being lost.

Why this exists: in Claude sessions, GitHub access is often scoped to *existing*
repos, and the `gh` CLI token may be missing or invalid, so "create a repo"
fails. This skill routes around that by creating the repo with whatever is signed
in (`gh` or the user's Chrome), then pushing through the session's git access.

---

## Modes

### Auto mode (default)

Use it when the user's message asks for a repo to be created or code to be published
("make a repo and push this", "publish this to GitHub", "you pick the name").
**That request is the approval.** Claude decides the details and runs the whole
flow without stopping to ask:

| Decision | Auto rule |
|---|---|
| Name | kebab-case from the project's purpose (`portfolio-site`, `issue-lens`), ≤ 40 chars |
| Name taken | Try `<name>-app`, `<name>-2`, … automatically and mention the final name |
| Description | One line, ≤ 100 chars, what it does |
| Visibility | Match the user's existing repos (`list_repos`). If they're all public, use public. If none exist or they're mixed, use **private** |
| Starting files | None; Claude pushes its own README / .gitignore |
| License | None, unless the user asks or says "anyone can use it" (then MIT) |

Auto mode **still stops and asks** only when one of these is true:
- The content looks private or sensitive (keys, `.env`, personal data, client
  work) and the visibility would be **public**. In that case, make it private or ask.
- The owner would be an **organization**, not the user's own account.
- A step would **delete, overwrite or force-push** anything that already exists.
- GitHub asks for a **password, 2FA code or sign-in**. The user does that part themselves.

### Confirm mode

Use it when the user says "show me first", "don't create yet", "let me check" or "draft it".
Fill everything in, then show owner/name, description and visibility before
clicking Create.

---

## Step 1: Check access (fastest route first)

```bash
gh auth status 2>&1 | head -5
```

- **Signed in**: create with the CLI, skip Step 2, and continue at Step 3.
  ```bash
  gh repo create OWNER/NAME --public --description "..."   # or --private
  ```
- **Not signed in, or "token is invalid"**: use the browser route (Step 2).
  Never log `gh` in with the user's password or a token.

---

## Step 2: Create the repo in the user's Chrome

1. Load the Claude in Chrome tools in ONE ToolSearch call
   (`tabs_context_mcp, navigate, computer, find, read_page, form_input, tabs_create_mcp, tabs_close_mcp`).
   Read the `chrome-browser` skill first if it is listed.
2. Run `tabs_context_mcp`, then work in a new tab. Don't use the user's own tabs.
3. Navigate to `https://github.com/new`. An avatar in the top-right means signed in.
   A login page means stop: the user signs in themselves.
4. `find` the fields "Repository name", "Description", "Choose visibility" and
   "Create repository".
5. Fill the name and description with `form_input`. It sets the exact value,
   while click + `type` can drop characters.
6. Set visibility. It is a dropdown button, not a form field, so `form_input`
   won't work. Click **Choose visibility**, click Public or Private, and check the
   button label. Leave README, .gitignore and license **off**.
7. **Verify**: screenshot and `zoom` on the name and description. Check that
   "✓ name is available" shows. Fix typos now.
8. Auto mode: click **Create repository**. Confirm mode: show the summary and wait.
9. Success means the URL is `github.com/OWNER/NAME` and the "Quick setup" page shows.
10. Close the tabs you opened.

---

## Step 3: Attach the repo

Cloud session: call `add_repo(owner=OWNER, repo=NAME, access="push")`, then clone
once with a long timeout (≈10 min):

```bash
git clone --depth 1 https://github.com/OWNER/NAME ./NAME
```

"You appear to have cloned an empty repository" is expected. Two fixes are
needed right after cloning an empty repo:

```bash
cd NAME
# a shallow clone of an empty repo has no fetch refspec, so origin/main never updates
git config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
# git may have started the branch as "master"; GitHub expects main
git checkout -q -B main
```

If the `register_repo_root` tool exists, call it with the clone's absolute path.

Local Claude Code: skip `add_repo`. The user's own git credentials can push.

---

## Step 3b: Self-healing fallback (existing repo unreachable)

When the work is meant for an **existing** repo and that repo can't be used,
don't stop. Create a new repo and store the work there.

**Triggers.** Any one is enough, after one honest retry where noted:

| Failure | Example |
|---|---|
| `add_repo` refuses | "not authorized", "not enabled for this organization", app not installed |
| Clone or fetch fails | `403`, `404 Repository not found`, `could not read Username` (retry once) |
| Push is denied | `Permission denied`, `403`, "repository archived", protected branch with no PR route |
| Repo deleted or renamed and no longer resolves | |

**Not triggers.** Fix these in place instead:
- `429`: sleep 5 s and retry once.
- `413`: `git fetch --depth=50 origin main`, rebase and push again.
- Merge conflicts, failing hooks, or a protected branch where a PR works.
  For a protected branch, push a branch and open a PR.

**Rescue steps**

1. **Name it.** Use `<original-name>-v2`, or `-v3` if that's taken. If the original
   name is unknown, derive one from the content.
2. **Pick visibility.** Copy the original's visibility if known; otherwise use
   **private**. Never make rescued data public unless the original was public
   or the user says so.
3. **Create it** with Step 1 or Step 2 (auto mode applies). In a cloud session,
   also run `add_repo(owner=OWNER, repo=NEW, access="push")`, because pushes only
   work for attached repos.
4. **Move the work:**
   - Original readable (cloned) but not writable: keep the history. A shallow
     clone **can't** be pushed to a new empty repo; GitHub rejects it with
     `shallow update not allowed`. Pull the full history first:
     ```bash
     git remote rename origin old-origin
     git remote add origin https://github.com/OWNER/NEW.git
     if [ "$(git rev-parse --is-shallow-repository)" = true ]; then
       git fetch --unshallow old-origin
     fi
     git -c push.negotiate=true push -u origin HEAD:main
     ```
     If `--unshallow` fails (hook, size, or access lost), push a snapshot instead.
     History is lost, but the files are safe:
     ```bash
     git checkout -q --orphan rescue-main
     git commit -qm "Rescued snapshot of OWNER/ORIGINAL"
     git -c push.negotiate=true push -u origin rescue-main:main
     ```
   - Original not readable at all: copy the local files into the new clone,
     commit them, and push.
   - Data only (no git yet): write it into the new clone, commit, and push.
5. **Leave a trail.** Add a line at the top of the README:
   `> Rescued from OWNER/ORIGINAL on YYYY-MM-DD: original repo was unreachable (<reason>).`
6. **Never touch the original.** Don't delete it, force-push to it or rename it.
7. **Tell the user** in one line: what failed, the new repo link, and that the
   original is untouched.

---

## Step 4: Build the content

- `README.md`: what it is, why, how to use it, the structure
- The actual code, skill or content
- `.gitignore` if the stack needs one (Python: `__pycache__/`, `.venv/`, `.env`;
  Node: `node_modules/`, `.env`, `dist/`)
- **Never** commit secrets: `.env`, tokens, `credentials.json` or API keys.
  If a secret is found, exclude it and say so.

---

## Step 5: Commit & push

```bash
cd NAME
git add -A
git status --short          # last check: no .env, keys or credentials listed
git commit -m "Initial commit: <what this is>"
git branch -M main          # guard: GitHub expects main, local git may say master
git -c push.negotiate=true push -u origin main
```

A `push negotiation failed` warning is only a warning. Look for `main -> main`.
If the session provides attribution lines, append them to the commit message.

---

## Step 6: Verify & hand off

1. `git ls-remote origin` should show the commit on the remote.
2. Optional polish: on the repo page, click ⚙ next to **About**. Set the
   description with `form_input` and add 4–6 topics separated by spaces. Click
   **Save changes**, then screenshot to confirm the dialog closed.
3. Report in 2–3 lines: the repo link, what's in it, and one next step. If the
   fallback ran, say so.

---

## Failure playbook

| Symptom | Fix |
|---|---|
| `gh` token invalid | Chrome route (Step 2) |
| Chrome tools missing or not responding | The user creates the empty repo at github.com/new, then continue from Step 3 |
| GitHub login page | The user signs in. Never type passwords |
| Name already exists | Auto-suffix (`-app`, `-2`) and mention it |
| Existing repo won't clone, fetch or push | Step 3b: rescue into a new repo |
| `add_repo` auth error for a **new** repo | Relay the reason and point to Settings → Connectors to reconnect GitHub |
| Clone 429 | Sleep 5 s, retry once |
| Push 413 | Fetch `--depth=50`, rebase, push |
| Browser actions fail 2–3 times | Stop and ask. Don't loop |

## Safety rules

- Auto mode creates without asking, but never makes sensitive content public.
- Never enter passwords, tokens or 2FA codes, and never commit secrets.
- Only create repos under the user's own account unless they name an org.
- Never delete, overwrite, rename or force-push an existing repo. The fallback
  always creates a **new** one.
