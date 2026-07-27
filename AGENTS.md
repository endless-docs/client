# Repository Role

This repository owns the Endless client: Flutter, Isar persistence, the local daemon, MCP integration, and CLI functionality.

## Project Scope Boundary

The Codex project for this repository must work only within this repository.

- Read, create, edit, delete, search, and run commands only inside this repository's root.
- Do not inspect, access, or modify `architecture`, `contracts`, `cloud`, `web`, `infra`, `e2e`, or any other sibling repository.
- Do not create, dispatch, or manage Codex tasks for sibling repositories.
- Do not bypass this boundary with absolute paths, parent-directory traversal, shared worktrees, or external tools.

Tasks may be assigned by the Codex project for the `architecture` repository. Implement only the client portion of such a task here. If completion requires work in another repository, describe the dependency and return it to the architecture project for coordination; do not perform that work directly.

## Current Git Workflow

At the current project phase, all repository changes must be pushed directly to `main` without workflow restrictions.

- At the end of every task that produces repository changes, immediately commit all intended changes and push the commit to `origin/main` before reporting the task as complete.
- Do not batch changes from multiple completed tasks into a later commit.
- Every commit message must follow Conventional Commits 1.0.0 using `<type>[optional scope]: <description>`.
- Use an appropriate lowercase type such as `feat`, `fix`, `docs`, `refactor`, `test`, `build`, `ci`, `chore`, `perf`, or `revert`; keep the description concise and imperative.
- Mark breaking changes with `!` before the colon and explain them in a `BREAKING CHANGE:` footer when applicable.
- Do not create feature branches or Pull Requests.
- Do not wait for reviews, approvals, CI checks, or other workflow gates before pushing.
- This temporary rule overrides repository documentation that requires branches, Pull Requests, reviews, approvals, or pre-push checks until the user explicitly changes this policy.
- If the remote technically rejects a direct push, report the rejection; do not silently push the change to another branch.
