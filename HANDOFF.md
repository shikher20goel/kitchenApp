# Rasoi — Launch Steps (do these on your Mac)

One action per step. Steps marked 🧑 are human-only.

## A. Put the kit in the repo

1. Open Terminal and run:
   `cd ~/Downloads/AppBuilder && gh repo clone shikher20goel/kitchenApp kitchen`
2. Run (the kit folder was placed next to it by our chat):
   `cp -R ~/Downloads/AppBuilder/kitchen-kit/. ~/Downloads/AppBuilder/kitchen/`
3. Run: `cd ~/Downloads/AppBuilder/kitchen && ls` — you should see CLAUDE.md, plan.md, prd.json,
   progress.txt, project.yml, docs/, seed/, scripts/.
4. Run: `bash scripts/verify.sh --build-only` is NOT expected to work yet (no sources) — skip it.

## B. Start the autonomous build

5. Run: `sudo pmset -a disablesleep 1`
6. Run: `cd ~/Downloads/AppBuilder/kitchen && claude --dangerously-skip-permissions`
7. Paste into the Claude Code session:
   `/ralph-loop:ralph-loop "Work the backlog in prd.json per CLAUDE.md. First read CLAUDE.md, plan.md and docs/SPEC.md, then start at task 000 (commit this kit as the first commit on branch autonomous-build and push)." --max-iterations 60 --completion-promise "PROJECT_COMPLETE"`
8. 🧑 Watch the first 10–15 minutes: it should read the plan, do tasks 000–005, run
   `bash scripts/verify.sh`, and commit. If it invents things, type `/cancel-ralph`.
9. If the loop stops early: re-paste the same command from step 7 (prd.json carries the state).
   Cancel anytime with `/cancel-ralph`.

## C. While it runs / when it finishes

10. 🧑 Review the HUMAN-gate docs as they appear (listed in progress.txt):
    docs/SEED-RECIPES.md (028) → docs/COPY-FEEDBACK.md (043) → docs/PRIVACY-MAPKIT.md (053) →
    docs/COPY-NUTRITION.md (058) → docs/REVIEW.md (066).
    Tell the Code session "approved: task 028" (etc.) after each.

## D. Install on your iPhone (after PROJECT_COMPLETE)

11. 🧑 Plug the iPhone 14 Pro into the Mac (Developer Mode on, tap Trust if asked).
12. In the Code session paste:
    "Install Rasoi on my iPhone: run scripts/configure-signing.sh free with my personal team ID,
    build with xcodebuild -allowProvisioningUpdates, then install with xcrun devicectl. My phone
    is connected by cable."
13. Run: `sudo pmset -a disablesleep 0`

## Notes

- Free Apple team = the app stops launching after 7 days; repeat step 12 weekly (or adapt the
  `north-phone-install` skill to Rasoi).
- Phase 2 (photo scan of fridge/pantry via Claude API, AI recipe ideas, barcode add, sync) is in
  docs/SPEC.md §10 — start it as a new orchestrator run after v1 has been used for two weeks.
