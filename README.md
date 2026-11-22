# claude-repo-launcher

A Claude skill that **creates a brand-new GitHub repo and publishes code to it** from start to finish, even when Claude's session isn't allowed to create repos.

Built in public by [Mayank Kontey](https://www.linkedin.com/in/mayank-kontey-312770370/).

---

## The problem

In a Claude session, the GitHub connection usually works **only with repos that already exist**. Claude can push to them, but it can't create a new one, and the `gh` CLI is often not signed in. So "make a repo and publish my code" stalls at step one.

## The fix

Make the new repo **in your own Chrome** (where you're already signed in to GitHub), then push through the session's normal git access.

```
check access ──► gh works?  ──yes──► gh repo create
      │
      no
      ▼
Chrome → github.com/new → fill form → confirm → Create
      ▼
attach repo to session → clone → build files → commit → push → verify
```

This repo was created with the skill itself.

## What's inside

```
claude-repo-launcher/
├── README.md
├── LICENSE           ← MIT: free to use, change and share
└── skills/
    └── repo-launcher/
        └── SKILL.md      ← the full workflow Claude follows
```

## Install (free for anyone)

### Option A: Claude.ai (web or desktop app)
1. Download [`skills/repo-launcher/SKILL.md`](skills/repo-launcher/SKILL.md).
2. Put it in a folder named `repo-launcher`, then zip the folder to get `repo-launcher.zip`.
3. In Claude, go to **Settings → Capabilities → Skills → Upload skill** and pick the zip.

### Option B: Claude Code (terminal)
```bash
git clone https://github.com/MAYANKKONTEY/claude-repo-launcher
mkdir -p ~/.claude/skills
cp -r claude-repo-launcher/skills/repo-launcher ~/.claude/skills/
```
Restart Claude Code. The skill loads automatically.

### Option C: one project only
Copy `skills/repo-launcher/` into your project's `.claude/skills/` folder.

### Requirements
- A GitHub account
- **One** of the following:
  - the `gh` CLI, signed in (`gh auth login`). This is the fastest route.
  - the **Claude in Chrome** extension, connected, with you signed in to GitHub in Chrome
- Without either, Claude asks you to create the empty repo yourself and handles everything after that.

## How to use it

Say something like:
   - *"Make a new repo for my portfolio site and push this code"*
   - *"Publish this project to GitHub, you pick the name"*

Claude fills in the form, **asks you before clicking Create**, then pushes and sends you the link.

## Safety

- Claude asks you before creating anything public under your name.
- Claude never types passwords, tokens or 2FA codes. If GitHub asks you to sign in, you do it.
- Claude never commits secrets (`.env`, API keys).
- Claude never deletes or overwrites existing repos.

## Lessons from building it

- **Check typed text before you submit.** In the first run, browser typing dropped a letter in the description. The skill now zooms in on the fields before clicking Create.
- **Start with an empty repo.** Without a README, license or .gitignore from GitHub, the first push is a clean fast-forward.
- **"push negotiation failed" is only a warning.** Look for `main -> main` to confirm the push worked.

## Roadmap

- [ ] Add `.gitignore` templates for Python, Node and Swift
- [ ] Turn on GitHub Pages automatically for static sites
- [ ] Set repo topics and description after creation
- [ ] Log each launch to [Build-in-public-365-day](https://github.com/MAYANKKONTEY/Build-in-public-365-day)
