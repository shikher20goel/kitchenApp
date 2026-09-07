# CLAUDE.md — Persistent rules for the Rasoi autonomous build

Completion promise: PROJECT_COMPLETE

## Project
Rasoi — private, local-first family kitchen planner for iPhone (household + diet settings,
seeded vegetarian recipe catalog, pantry with shelf life, deterministic weekly meal planner that
learns from per-child feedback, grocery list by store, MapKit store finder, MyPlate coverage dots).
**docs/SPEC.md is the pin. When in doubt, the SPEC decides — do not invent features.**
Repo: github.com/shikher20goel/kitchenApp · branch `autonomous-build` · local ~/Downloads/AppBuilder/kitchen

## Stack & conventions
- SwiftUI + SwiftData, iOS 26.0 min, single app target `Rasoi` (+ RasoiTests, RasoiUITests).
- Project is GENERATED: edit `project.yml`, run `xcodegen generate`. NEVER hand-edit .xcodeproj.
- Zero external dependencies. The ONLY network-capable code allowed is MapKit/CoreLocation inside
  `Rasoi/Services/StoreFinder.swift` (red line R1). No URLSession anywhere. No entitlements.
- MVVM-lite: Views → ViewModels → pure-Swift Engines (`Rasoi/Engines/`) → SwiftData. Engines take
  plain structs/snapshots and are deterministic; keep Views thin.
- Seed content is data: `seed/ingredients.json`, `seed/recipes.json` (bundled resources). Fix data
  bugs in the JSON, never by special-casing recipes in code.
- All user-facing copy for settings/about/feedback/nutrition/notifications lives in
  `Rasoi/Copy/AppCopy.swift` (HUMAN-reviewed). Tone: warm, neutral, never shaming a child (R3),
  never calories/weight/diet-restriction language (R2).
- Layout: `Rasoi/App`, `Rasoi/Design`, `Rasoi/Data` (models, Persistence, Seed), `Rasoi/Engines`,
  `Rasoi/Services`, `Rasoi/Features/<Feature>/` (View + ViewModel), `Rasoi/Copy`.
- Simulator names drift: always detect via `xcrun simctl list devices available --json`
  (verify.sh does this).

## Verify command
`bash scripts/verify.sh`  (xcodegen generate → xcodebuild build → test on an auto-detected iPhone
simulator). Scope with `--unit`, `--build-only`, or `bash scripts/verify.sh RasoiTests/FooTests`.

## How to work (every iteration)
1. Read this file and prd.json. Pick the lowest-numbered task whose passes=false and whose
   dependencies all pass (HUMAN dependencies count as satisfied once implemented — see 3).
2. AUTO task: implement following existing patterns. Make a GENERAL, root-cause fix — never the
   minimum hack to pass one test. Tests are authored in the "Tests:" task before the "Implement:"
   task; do not rewrite tests to fit code unless a test contradicts docs/SPEC.md (then note it in
   progress.txt). No new dependencies. Don't touch the data model unless the task says so.
3. HUMAN task: produce the review artifact it names (docs/…md), do NOT mark passing, do NOT
   treat it as approved. Append "TASK <id> implemented, awaiting human review" to progress.txt and
   move to the next eligible AUTO task. When Shikher replies "approved: task <id>", set passes=true.
4. Run the task's done-check exactly. On pass: set passes=true in prd.json (use
   `python3 scripts/mark-task.py <id>`), commit + push to origin autonomous-build, note in
   progress.txt. On fail: fix the cause, re-run; after 5 tries, log the blocker and move on.
5. Re-read progress.txt before each task to avoid repeating mistakes.
6. Emit PROJECT_COMPLETE only when every AUTO task passes AND `bash scripts/verify.sh` is green
   AND only HUMAN tasks remain unapproved.

## Grounding
- Human work idioms do not apply: no "break", no "end of workday". Keep executing.
- "I believe it's done" is not done. "Every done-check passes" is done. Re-verify before the promise.
- Green tests ≠ working app: task 065's simulator smoke-run with screenshots is mandatory.
- Determinism (R5): planner/scorer/list builder must give identical output for identical input.

## Forbidden autonomous actions (never without a human)
- Any network code outside StoreFinder.swift; any AI/LLM call; any third-party SDK (R1)
- Adding dependencies, targets, extensions, entitlements; hand-editing .xcodeproj
- Sending household data anywhere; committing real family data (fixtures/screenshots use the demo
  household: 2 adults, kids born 2022-03-01 and 2017-06-15)
- Deleting user data, feedback history or pantry outside the explicit Delete-all-data flow (R6)
- Showing calories, weight, BMI, or restriction language anywhere (R2); shaming copy (R3)
- Pushing to main; merging HUMAN-gated work; committing secrets or a real Apple team ID

## Human-review domains (always HUMAN-gated)
Seed recipes/ingredients (028) · feedback & settings copy (043) · MapKit privacy path (053) ·
nutrition & insights copy (058) · final review + device install (066).

## Install (free Apple team, CLI only — run when Shikher says the phone is cabled)
```
bash scripts/configure-signing.sh free <TEAM_ID>
xcodegen generate
xcodebuild -project Rasoi.xcodeproj -scheme Rasoi -destination 'generic/platform=iOS' \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration DEVELOPMENT_TEAM=<TEAM_ID> \
  CODE_SIGN_STYLE=Automatic -derivedDataPath build/ build
xcrun devicectl list devices
xcrun devicectl device install app --device <UDID> build/Build/Products/Debug-iphoneos/Rasoi.app
```
"connected (no DDI)" = Developer Mode off on the iPhone. Free team ⇒ reinstall every 7 days.
