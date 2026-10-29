# Kosmosekuller development

Use the existing checkout in this isolated cloud task. Do not create a Git worktree unless the user explicitly requests it.

The user wants a browser-playable version after every game update. Preserve that workflow:

- Run `./tools/build_web.sh` and the relevant gameplay/browser checks after changing the game. Keep `build/web` playable and preserve the portrait layout.
- `.github/workflows/web.yml` builds, tests and publishes changes pushed to `main` to GitHub Pages. Review the diff and preserve user work before committing or pushing. Publishing game updates is requested by the user; do not ask for that permission again during this project.
- The one-time hosting setup is in `docs/WEB.md`. Do not change repository visibility, invent credentials or disable verification to make hosting work.
- After deployment, verify the real site using `tools/verify_web.py` and the expected content fingerprint. Give the user the actual verified URL. Distinguish a locally built game, a successful push, a running workflow and a confirmed live deployment.
- If credentials, GitHub Pages setup or enforced network policy block deployment, finish the local build and configuration, then report the exact missing prerequisite. Do not describe an expected URL as live.
