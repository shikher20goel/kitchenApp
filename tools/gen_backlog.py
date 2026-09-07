#!/usr/bin/env python3
"""Generates plan.md and prd.json for the Rasoi autonomous build from one task table."""
import json, re

V = "bash scripts/verify.sh"
PROMISE = "PROJECT_COMPLETE"
T = []  # (id, title, milestone, deps, context, do, dont, done, gate)
def t(title, ms, deps, ctx, do, dont, done, gate="AUTO"):
    T.append(dict(id=f"{len(T):03d}", title=title, milestone=ms, depends_on=[f"{d:03d}" for d in deps],
                  context=ctx, do=do, dont=dont, done=done, gate=gate))

MS = {
 "M0":"Scaffold + harness","M1":"Data model + persistence","M2":"Seed catalog + diet filter","M3":"Household, settings, onboarding",
 "M4":"Pantry","M5":"Recipes browse + cook mode","M6":"Kid scores + feedback","M7":"Meal planner","M8":"Grocery list + stores",
 "M9":"Today + nutrition coverage + insights","M10":"Notifications, export, polish","M11":"Audit, review, install"}

# ---------------- M0
t("Init repo on branch autonomous-build: README, .gitignore, docs/, seed/ committed","M0",[],
  "Repo github.com/shikher20goel/kitchenApp is cloned at ~/Downloads/AppBuilder/kitchen with this kit (docs/SPEC.md, plan.md, prd.json, CLAUDE.md, progress.txt, project.yml, scripts/, seed/) unpacked but uncommitted.",
  "git checkout -b autonomous-build (if not already). Write README.md (2 paragraphs: what Rasoi is, how to build/verify/install — copy the command block from CLAUDE.md). .gitignore: build/, DerivedData, *.xcodeproj/xcuserdata, .DS_Store, *.xcuserstate, docs/screenshots/*.png is KEPT. Commit everything as 'Rasoi kit: spec, backlog, seed data' and push -u origin autonomous-build.",
  "Do not touch main. Do not edit seed/*.json in this task.",
  "`git branch --show-current` prints autonomous-build; `git status --porcelain` empty; `git log origin/autonomous-build --oneline | head -1` shows the commit.")
t("project.yml → `xcodegen generate` produces Rasoi.xcodeproj with 3 targets","M0",[0],
  "project.yml is in the kit (Rasoi app + RasoiTests + RasoiUITests, iOS 26.0, seed/ bundled as app resources). Rasoi/ has no sources yet.",
  "Create Rasoi/App/RasoiApp.swift (@main, WindowGroup showing Text(\"Rasoi\")) and Rasoi/Resources/Assets.xcassets with AppIcon + AccentColor (placeholder saffron #E8A33D). Run xcodegen generate. Fix project.yml only if generation fails.",
  "Do not hand-edit Rasoi.xcodeproj. Do not add targets.",
  "`xcodegen generate` exits 0 and Rasoi.xcodeproj/project.pbxproj lists targets Rasoi, RasoiTests, RasoiUITests.")
t("App skeleton: 5-tab ContentView + Theme tokens","M0",[1],
  "RasoiApp.swift exists. SPEC §4 defines tabs Today · Plan · Pantry · Shop · More; §8 the design language.",
  "Add Rasoi/App/ContentView.swift with a TabView of 5 placeholder screens (each a NavigationStack with a title) using SF Symbols sun.max, calendar, refrigerator, cart, ellipsis.circle. Add Rasoi/Design/Theme.swift: appName = \"Rasoi\", colours (saffron accent, sage, cream, surfaces), spacing scale, corner radii, a `.rasoiCard()` view modifier, haptic helper.",
  "No feature logic. No third-party fonts.",
  "`xcodebuild -project Rasoi.xcodeproj -scheme Rasoi -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` succeeds.")
t("scripts/verify.sh works end-to-end with one trivial passing test","M0",[2],
  "scripts/verify.sh is copied from North (simulator autodetect → xcodegen → build → test). RasoiTests has no tests.",
  "Add RasoiTests/SmokeTests.swift with `testHarnessIsAlive` asserting true and `testThemeAppName` asserting Theme.appName == \"Rasoi\". Add RasoiUITests/LaunchUITests.swift that launches the app and asserts the tab bar exists. Run verify.sh; fix scheme/test-host wiring in project.yml if needed.",
  "Do not disable tests to get green. Do not hard-code a simulator name.",
  "`bash scripts/verify.sh` exits 0 and prints ≥2 passed test cases.")
t("scripts/configure-signing.sh free|full modes","M0",[1],
  "Copied from North; references bundle prefix and app name. It rewrites DEVELOPMENT_TEAM / bundle IDs in project.yml and regenerates.",
  "Adapt for Rasoi (target names, bundle com.shikhergoel.rasoi). `free <TEAM_ID>` sets the team, automatic signing, no entitlements; `full <TEAM_ID>` same plus reserved hook for Phase 2 entitlements (none in v1).",
  "No entitlements file in v1. Do not commit a real team ID (script takes it as an argument).",
  "`bash scripts/configure-signing.sh free ABCDE12345 && xcodegen generate` exits 0; `git diff project.yml` shows only the team line; then `git checkout project.yml`.")
t("SwiftData PersistenceController + in-memory test factory","M0",[3],
  "No models yet. North's pattern: Persistence.swift exposing `shared` (on-disk) and `makeInMemory()` for tests.",
  "Add Rasoi/Data/Persistence.swift with a ModelContainer factory taking the schema list (empty for now) and `static func inMemory() throws -> ModelContainer`. Add RasoiTests/Support/TestContainer.swift helper. Test: container creates and a context can save.",
  "No models in this task.",
  f"`{V} RasoiTests/PersistenceTests` green.")

# ---------------- M1 data model (tests before models, per pair)
models = [
 ("HouseholdMember + AgeBand", "HouseholdMember per SPEC §3; Rasoi/Engines/AgeBand.swift: pure func band(dob:on:) with bands preschool 2–5, child 6–8, preteen 9–13, teen 14–18, adult; plus `years(dob:on:)`.", "AgeBandTests: boundaries at each birthday, leap-day DOB, adult; HouseholdMemberTests: insert/fetch, sortOrder, isActive filter."),
 ("DietProfile singleton with SPEC defaults", "DietProfile per SPEC §3 with `static func current(in:)` that creates the singleton with defaults (vegetarian true, eggsOK true, dairyOK true, zip 07302, Sunday, 35 min, appliances instantPot/vitamix/stovetop/oven, 5 cuisines).", "DietProfileTests: defaults, singleton idempotent (two calls → one row), excludedIngredients round-trip."),
 ("Store model + default store seed", "Store per SPEC §3 + StoreSeeder.seedDefaultsIfEmpty(in:) inserting the 6 default stores with categoryAffinity (indian → legume, spice, flourBread, dairy(paneer); hispanic → flourBread(tortillas), vegetable; eastAsian → legume(tofu), oilCondiment, grain(noodles); supermarket/warehouse → everything else).", "StoreTests: seed inserts 6, re-seed inserts 0, sortOrder stable, isPreferred default true for Walmart/Costco/Stop & Shop."),
 ("Ingredient model", "Ingredient per SPEC §3 (unique name, aliases, category enum, flags, tags, isQuickHealthySnack).", "IngredientTests: category enum round-trip, unique name constraint, alias lookup helper returns the row for 'toor' → Toor dal."),
 ("PantryItem model + ShelfLife engine", "PantryItem per SPEC §3; Rasoi/Engines/ShelfLife.swift: expiry(from:addedAt:location:) = shelf days ×1 fridge/pantry, ×6 freezer; isExpiringSoon(within: 2 days).", "ShelfLifeTests: freezer multiplier, expiring-soon boundary; PantryItemTests: unique per ingredient+location upserts quantity."),
 ("Recipe + RecipeIngredient models", "Recipe per SPEC §3 with RecipeIngredient as a Codable struct array; computed totalMinutes, isQuick. seedID unique when non-nil.", "RecipeTests: insert with 3 ingredients, totalMinutes, isQuick boundary at 15, seedID uniqueness."),
 ("MealPlan, MealSlot, MealFeedback models", "Per SPEC §3: MealPlan unique weekStart (Monday), MealSlot unique date+mealType, reasons [String], lockedByUser, status; MealFeedback unique slot+member. Helper `MealPlan.weekStart(containing:)` returns the Monday.", "MealPlanTests: weekStart(containing:) for each weekday incl. Sunday→previous Monday; slot uniqueness; feedback uniqueness upsert."),
 ("GroceryList + GroceryItem models", "Per SPEC §3: GroceryList unique weekStart; GroceryItem with neededFor, isChecked/checkedAt, store optional, addedManually, isStapleTopUp.", "GroceryListTests: insert, check item sets checkedAt, unique weekStart."),
 ("AppSettings singleton", "AppSettings per SPEC §3 with defaults (shopping reminder ON Sat 18:00, cook reminder OFF 16:30, master switch ON).", "AppSettingsTests: defaults + singleton idempotence."),
]
prev = 5
for name, impl, tests in models:
    t(f"Tests: {name}","M1",[prev],
      f"Model does not exist yet. Persistence.swift schema list is where models are registered.",
      f"Write the RasoiTests test file(s) described here FIRST (they will fail to compile until the next task): {tests} Use TestContainer.",
      "Do not implement the model in this task beyond an empty stub if needed for compilation of unrelated tests.",
      "Test file(s) exist and reference the API named in the next task; `bash scripts/verify.sh --build-only` may fail — acceptable ONLY for this task pair.")
    t(f"Implement: {name}","M1",[len(T)-1],
      "Tests from the previous task define the API.", f"Implement: {impl} Register in Persistence.swift schema.",
      "Do not change the tests to fit the code unless the test contradicts SPEC §3. Do not add fields beyond SPEC.",
      f"`{V} --unit` green (all tests so far).")
    prev = len(T)-1
M1_END = prev

# ---------------- M2 seed + diet filter
t("Tests: SeedLoader decodes seed/*.json and validates cross-references","M2",[M1_END],
  "seed/ingredients.json (~185) and seed/recipes.json (51) are bundled resources of the Rasoi target. Every recipe ingredientName must match an Ingredient name.",
  "RasoiTests/SeedLoaderTests: decodes both files from Bundle.main; ingredient count ≥180; recipe count ≥50; every RecipeIngredient.ingredientName resolves to an ingredient; no recipe contains any of [chicken, beef, pork, fish, shrimp, egg?→ only if containsEgg true]; ≥10 breakfast, ≥30 lunch/dinner, ≥8 snack, ≥12 instantPot, ≥5 vitamix recipes; all seedIDs unique.",
  "Do not edit the JSON to make tests pass without noting it in progress.txt.",
  "Tests written; may not compile yet.")
t("Implement: SeedLoader (Codable DTOs) + SeedImporter idempotent upsert","M2",[len(T)-1],
  "DTOs mirror the JSON keys exactly. SeedImporter maps DTO → Ingredient/Recipe rows keyed by name/seedID; DietProfile.seedVersion records the applied version.",
  "Rasoi/Data/Seed/SeedDTOs.swift, SeedLoader.swift, SeedImporter.swift with `importIfNeeded(in:)` (skips when seedVersion matches) and `reimport(in:)` (upsert, never duplicates, preserves user edits to isFavorite/isHidden). Add SeedImporterTests: import twice → same counts; favourite survives reimport.",
  "Never delete user-created recipes on reimport.",
  f"`{V} RasoiTests/SeedLoaderTests RasoiTests/SeedImporterTests` green.")
t("Tests: DietFilter engine","M2",[len(T)-1],
  "SPEC §5 DietFilter: vegetarian hard filter, egg/dairy/nut/gluten toggles, excludedIngredients alias-aware, minAge vs youngest diner, appliances subset.",
  "RasoiTests/DietFilterTests over plain structs (no SwiftData): each rule in isolation + a combined case; excluded 'palak' hides Palak Paneer via alias; missing Vitamix hides vitamix-only recipes; egg recipe hidden when eggsOK false.",
  "Pure structs only.", "Tests written.")
t("Implement: DietFilter engine","M2",[len(T)-1],
  "Engines are pure Swift in Rasoi/Engines/. Input: RecipeSummary struct + DietRules struct + IngredientIndex (name/alias → category/flags).",
  "Rasoi/Engines/DietFilter.swift `eligible(_:rules:index:youngestAgeYears:) -> Bool` + `reasonRejected(...)-> String?`. Add `RecipeSummary.init(recipe:)` mapping.",
  "General rule implementation; no per-recipe special cases.", f"`{V} RasoiTests/DietFilterTests` green.")
t("HUMAN: review seed recipes and ingredient catalog","M2",[len(T)-1],
  "51 recipes + 185 ingredients were authored by the orchestrator; a human must confirm they are healthy, vegetarian, kid-appropriate and match the household.",
  "Generate docs/SEED-RECIPES.md: table of every recipe (title, cuisine, meals, appliances, minutes, minAge, egg/dairy/nuts/gluten, kidBaseline, kid note) and a summary of ingredient categories/counts, plus a list of anything the loop flagged as questionable. Do not change recipes.",
  "Do not mark passing.", "FLAG FOR HUMAN REVIEW — Shikher approves docs/SEED-RECIPES.md.", "HUMAN")
M2_END = len(T)-1

# ---------------- M3 household/settings/onboarding
t("Family screen: list, add/edit member (name, DOB, role, likes/dislikes, avatar)","M3",[M2_END-1],
  "Models exist. More tab placeholder exists.",
  "Rasoi/Features/Family/FamilyListView.swift + MemberEditView.swift + FamilyViewModel.swift. DOB via DatePicker; likes/dislikes as chip input (comma or return adds). Show age band label (e.g. '4 · preschool'). Add FamilyViewModelTests (add, edit, reorder, deactivate).",
  "No deletion of members with feedback history — deactivate instead (R6).", f"`{V} RasoiTests/FamilyViewModelTests` green; app builds.")
t("Diet & Kitchen settings screen","M3",[len(T)-1],
  "DietProfile singleton exists.",
  "Rasoi/Features/Settings/DietSettingsView.swift: vegetarian toggle (on, disabled, footnote 'v1 is vegetarian-only'), eggs/dairy/nut-free/gluten-free toggles, excluded ingredients (type-ahead from Ingredient catalog with aliases), appliances multi-select, cuisines multi-select, weekday max cook minutes stepper (15–90), shopping weekday picker, zip code field (5-digit validation). ViewModel + DietSettingsViewModelTests (zip validation, exclusion add/remove).",
  "No network. Do not call MapKit here.", f"`{V} RasoiTests/DietSettingsViewModelTests` green.")
t("Onboarding flow (first launch) + hasCompletedOnboarding gate","M3",[len(T)-1],
  "SPEC §4.6: members+DOB → diet toggles → appliances → zip + stores → 'Generate my first week' (planner not built yet: button finishes onboarding and lands on Plan tab with a 'Generate week' call-to-action).",
  "Rasoi/Features/Onboarding/OnboardingFlow.swift (4 pages, progress dots, skip allowed on every page except at least one member). Sets hasCompletedOnboarding. ContentView shows onboarding when false. OnboardingUITests: complete flow with one adult + one child ends on the tab bar.",
  "Keep copy short; no marketing tone.", f"`{V} RasoiUITests/OnboardingUITests` green.")
t("More tab: menu (Family, Diet & Kitchen, Stores, Recipes, Insights, Notifications, Appearance, About, Export, Delete all data)","M3",[len(T)-1],
  "Individual screens are built in later tasks; link placeholders are fine.",
  "Rasoi/Features/More/MoreView.swift with grouped List; About shows the R2 note verbatim from Rasoi/Copy/AppCopy.swift (create it — ALL user-facing copy strings for settings/about/feedback live here for the human gate). Delete all data: double-confirm, wipes every entity then reseeds catalog + stores.",
  "Delete all data must never be reachable in one tap.", f"`{V} --unit` green; app builds.")
M3_END = len(T)-1

# ---------------- M4 pantry
t("Tests: PantryViewModel (search-add with aliases, quantity, locations, expiring sort, mark used / ran out)","M4",[M3_END],
  "PantryItem + Ingredient + ShelfLife exist.",
  "RasoiTests/PantryViewModelTests: search 'toor' finds Toor dal; add sets expiresAt from shelf life; add same ingredient+location increments; 'ran out' removes non-staple, zeroes staple; expiring-soon sort order; segmented filter by location.",
  "", "Tests written.")
t("Implement: PantryViewModel","M4",[len(T)-1],"Tests define API.",
  "Rasoi/Features/Pantry/PantryViewModel.swift implementing the tested behaviour over a ModelContext.",
  "General implementation; alias matching via a shared IngredientIndex, not duplicated logic.", f"`{V} RasoiTests/PantryViewModelTests` green.")
t("Pantry screen UI","M4",[len(T)-1],"ViewModel exists.",
  "PantryView.swift: segmented Fridge/Pantry/Freezer, search bar with type-ahead add sheet (quantity + unit + location), rows with quantity stepper, expiry chip (green/amber/red by days), swipe actions Mark used / Ran out, sort toggle (name / expiring). Disabled 'Scan fridge' toolbar button with 'Coming later' footnote. PantryUITests: add an item via search, see it in the list.",
  "No camera code.", f"`{V} RasoiUITests/PantryUITests` green.")
M4_END = len(T)-1

# ---------------- M5 recipes browse + cook mode
t("Recipes browser: list, filters (meal, cuisine, appliance, quick, kid favourites), search, detail","M5",[M2_END-1, M3_END],
  "Recipes are seeded; DietFilter exists. Hidden/ineligible recipes must not appear in the default list (toggle 'show all' reveals with a reason label).",
  "Rasoi/Features/Recipes/RecipeListView.swift, RecipeDetailView.swift (ingredients with 'in pantry' ticks, steps, kid note, tags, favourite/hide), RecipesViewModel + RecipesViewModelTests (filters combine, search by title/ingredient, ineligible hidden by default, favourite toggles persist).",
  "Do not build the editor in this task.", f"`{V} RasoiTests/RecipesViewModelTests` green.")
t("Recipe editor: add/edit user recipes","M5",[len(T)-1],"Browser exists.",
  "RecipeEditView.swift: title, cuisine picker, meal types, appliances, prep/cook minutes, servings, minAge, ingredient rows (type-ahead from catalog, qty, unit, optional), steps (reorderable), kid note. Derives contains* flags from ingredients automatically. RecipeEditorTests: derived flags, validation (title + ≥1 ingredient + ≥1 step).",
  "User recipes have source=user and no seedID.", f"`{V} RasoiTests/RecipeEditorTests` green.")
t("Cook mode: one step per screen, large type, keep-awake, servings scaler","M5",[len(T)-1],"RecipeDetail exists.",
  "CookModeView.swift: full-screen, step N of M, swipe/arrow navigation, Dynamic Type XXL friendly, UIApplication.isIdleTimerDisabled while presented, ingredient quantities scaled by a servings stepper (Engines/Scaling.swift, pure, with ScalingTests: 4→6 servings, rounding to 0.25 for counts / 5 g for grams).",
  "No timers with notifications in v1.", f"`{V} RasoiTests/ScalingTests` green; CookMode reachable from RecipeDetail in a UI test.")
M5_END = len(T)-1

# ---------------- M6 feedback + kid score
t("Tests: KidScore engine","M6",[M1_END],
  "SPEC §5 KidScore: ateAll +1, ateSome +0.4, notToday −1, half-life 60 days, baseline blend n/(n+3), resting after 3 consecutive notToday from every child for 30 days.",
  "RasoiTests/KidScoreTests over plain structs: no feedback → baseline-only value; one ateAll moves score up by the blended amount exactly; decay halves weight at 60 days; resting rule triggers and expires; household score = mean over children.",
  "Pure structs; deterministic dates injected.", "Tests written.")
t("Implement: KidScore engine","M6",[len(T)-1],"Tests define API.",
  "Rasoi/Engines/KidScore.swift with `score(recipe:for:feedback:baseline:on:)`, `householdScore(...)`, `isResting(...)`; document the formula in a doc comment.",
  "No stored scores (computed only).", f"`{V} RasoiTests/KidScoreTests` green.")
t("Feedback sheet after cooking (per member: Ate it all / Ate some / Not today + note)","M6",[len(T)-1, M5_END],
  "MealSlot + MealFeedback exist. Copy lives in Rasoi/Copy/AppCopy.swift (R3: warm, neutral).",
  "FeedbackSheet.swift + FeedbackViewModel: one row per active member with three big buttons, optional note, saves MealFeedback upsert; marking slot cooked triggers PantryDepletion (next task) — wire the hook now as a protocol. FeedbackViewModelTests: upsert per member, reaction change overwrites, no member skipped silently (unanswered = no row).",
  "Never show scores or 'streaks' in this sheet.", f"`{V} RasoiTests/FeedbackViewModelTests` green.")
t("PantryDepletion engine + tests (cooked slot decrements pantry)","M6",[len(T)-1, M4_END],
  "SPEC §5 PantryDepletion: scaled recipe quantities subtracted, floor 0, remove at 0 unless staple; unit normalisation shared with GroceryBuilder.",
  "Rasoi/Engines/Units.swift (g/kg, ml/l, count, cup→ml table, tbsp/tsp) with UnitsTests; Rasoi/Engines/PantryDepletion.swift with PantryDepletionTests (partial, exact, over-consume, staple stays at 0, optional ingredients ignored).",
  "General conversion table, not per-ingredient hacks.", f"`{V} RasoiTests/UnitsTests RasoiTests/PantryDepletionTests` green.")
t("HUMAN: review feedback + about/settings copy","M6",[len(T)-1],
  "All copy is in Rasoi/Copy/AppCopy.swift.",
  "Generate docs/COPY-FEEDBACK.md listing every string in AppCopy.swift with its screen and the R2/R3 rule it must satisfy.",
  "Do not mark passing.", "FLAG FOR HUMAN REVIEW — Shikher approves docs/COPY-FEEDBACK.md.", "HUMAN")
M6_END = len(T)-2

# ---------------- M7 planner
t("Tests: MealPlanner rules (variety, weekday time cap, pantry-first, use-it-up, kid score ranking, sure-thing/new quotas, nutrition balance, breakfast rotation, determinism)","M7",[M6_END, M2_END-1],
  "SPEC §5 MealPlanner. Inputs are plain structs: eligible RecipeSummary list, PantrySnapshot, kidScores [seedID: Double], history (last 21 days), rules (weekday cap), week start date.",
  "RasoiTests/MealPlannerTests: one test per numbered rule with a tiny synthetic catalog (8–12 recipes), plus: locked slots untouched; regenerate keeps locked; same input → identical output (run twice); every slot has ≥1 reason string; full-catalog smoke test using the real seed produces 28 slots with no nil dinner and no repeat within 3 days.",
  "Do not test through SwiftData; pure engine only.", "Tests written.")
t("Implement: MealPlanner engine","M7",[len(T)-1],"Tests define behaviour; rules and priority in SPEC §5.",
  "Rasoi/Engines/MealPlanner.swift: candidate scoring per slot = weighted sum (pantry match, expiring bonus, kid score, variety penalty, time-cap hard filter, nutrition need bonus) with deterministic tie-break on seedID; a `PlanExplanation` (reasons) per slot; quotas enforced in a second pass. Document weights in one table at the top of the file.",
  "No randomness. General rule implementation — no special-casing test recipes.", f"`{V} RasoiTests/MealPlannerTests` green.")
t("PlanViewModel: generate/regenerate week, swap, lock, skip, eating out, persist slots","M7",[len(T)-1],
  "Engine is pure; VM bridges SwiftData ↔ engine (build snapshots, write MealSlots).",
  "Rasoi/Features/Plan/PlanViewModel.swift + PlanViewModelTests (generate creates 28 slots for the week; regenerate preserves locked; swap lists ≥3 alternatives ranked with reasons; skip/eatingOut statuses; next week generation uses feedback from this week — a notToday×3 recipe drops in rank).",
  "", f"`{V} RasoiTests/PlanViewModelTests` green.")
t("Plan screen UI: 7×4 grid, slot sheet, why-this, lock, week summary","M7",[len(T)-1],
  "VM exists. SPEC §4.2.",
  "PlanView.swift (horizontal day columns or vertical day sections — pick vertical days with 4 rows for one-handed use), SlotSheet.swift (alternatives with reasons, lock/skip/eating out), WeekSummaryCard (sure-things, new, nutrition dots placeholder until M9). PlanUITests: generate week → 7 days visible → tap a dinner → swap → title changes.",
  "", f"`{V} RasoiUITests/PlanUITests` green.")
M7_END = len(T)-1

# ---------------- M8 grocery + stores
t("Tests: GroceryBuilder (aggregate, scale, normalise, subtract pantry, staples, store assignment, idempotent merge)","M8",[M7_END],
  "SPEC §5 GroceryBuilder. Pure engine over PlanSnapshot + PantrySnapshot + IngredientIndex + StoreSnapshot.",
  "RasoiTests/GroceryBuilderTests: two recipes sharing onion aggregate; servings scaling; g vs kg normalise; pantry subtraction to zero removes line; staple below threshold added with isStapleTopUp; store assignment by affinity then fallback; merge into an existing list keeps checked items checked and never duplicates; cooked slots excluded.",
  "", "Tests written.")
t("Implement: GroceryBuilder engine","M8",[len(T)-1],"Tests define API; Units.swift exists.",
  "Rasoi/Engines/GroceryBuilder.swift producing [GroceryLine] + merge function.",
  "General logic; no ingredient-specific branches.", f"`{V} RasoiTests/GroceryBuilderTests` green.")
t("ShopViewModel + Shop screen (by store → category, check-off restocks pantry, why?, manual add, share text)","M8",[len(T)-1, M4_END],
  "Engine exists; checking an item creates/increments PantryItem with ShelfLife expiry; unchecking reverses within the same session.",
  "ShopViewModel + ShopViewModelTests (build from plan; check → pantry increment; uncheck → decrement; manual add; share text format grouped by store). ShopView.swift with store sections, category subsections, haptic check, 'Why?' popover listing neededFor, share sheet.",
  "", f"`{V} RasoiTests/ShopViewModelTests` green; ShopUITests checks one item.")
t("Stores screen: list/reorder/edit, category affinity editor","M8",[M3_END],
  "Store model + defaults exist.",
  "StoresView.swift + StoreEditView.swift + StoresViewModel + tests (reorder persists sortOrder; toggling isPreferred; affinity edit).",
  "No MapKit yet.", f"`{V} RasoiTests/StoresViewModelTests` green.")
t("StoreFinder protocol + MapKit implementation + fake for tests","M8",[len(T)-1],
  "SPEC §4.5: zip → CLGeocoder → MKLocalSearch queries ['grocery','supermarket','Indian grocery','Spanish grocery','Asian grocery'] within 8 km; results dedup by name+address; nothing persisted until the user taps Add. R1 allows only this network path.",
  "Rasoi/Services/StoreFinder.swift (protocol StoreFinding; MapKitStoreFinder; FakeStoreFinder in tests). Kind inference from query/name keywords (indian/patel/desi → indian; spanish/latino/bodega/supermercado → hispanic; asian/chinese/h mart/korean → eastAsian; costco/bj's/sam's → warehouse). StoreFinderTests over the fake: dedup, kind inference, radius filter.",
  "No other network APIs. No location permission prompt when a zip code is present.", f"`{V} RasoiTests/StoreFinderTests` green.")
t("Find nearby UI + HUMAN privacy check of the MapKit path","M8",[len(T)-1],
  "Finder exists.",
  "FindStoresSheet.swift: zip prefilled from DietProfile, search button, list of results with kind chip and distance, Add button per row. Also write docs/PRIVACY-MAPKIT.md: exactly what leaves the device (search strings + a coordinate derived from the zip), when (only on tap), and what is stored.",
  "Do not mark passing.", "FLAG FOR HUMAN REVIEW — Shikher approves docs/PRIVACY-MAPKIT.md after seeing real results for 07302 in the simulator.", "HUMAN")
M8_END = len(T)-2

# ---------------- M9 today + nutrition + insights
t("Tests: NutritionCoverage engine (MyPlate group hits per child per day, weekly 'light on X')","M9",[M7_END],
  "SPEC §5 NutritionCoverage; R2 forbids quantities/calories in UI — engine returns booleans per group per day and one weekly hint key.",
  "RasoiTests/NutritionCoverageTests: day with khichdi+fruit snack+yogurt covers grain/protein/veg/fruit/dairy; day with only pasta lacks fruit+protein; weekly hint picks the group missing on most days; age band targets table present for preschool/child/preteen/adult.",
  "", "Tests written.")
t("Implement: NutritionCoverage engine","M9",[len(T)-1],"Tests define API.",
  "Rasoi/Engines/NutritionCoverage.swift mapping ingredient categories/nutritionTags → MyPlate groups (fruit, vegetable, grain(+wholeGrain flag), protein (legume/paneer/egg/tofu/nutSeed/dairy-protein), dairy).",
  "Never output numbers of cups/oz to the UI layer.", f"`{V} RasoiTests/NutritionCoverageTests` green.")
t("Quick-snack + expiring-soon engines and Today screen","M9",[len(T)-1, M4_END, M6_END],
  "SPEC §4.1. Quick snacks come from pantry items tagged isQuickHealthySnack plus quick (≤15 min) snack recipes whose ingredients are all in pantry.",
  "Rasoi/Engines/QuickSnacks.swift + tests (top 3, prefers fruit first, then a Vitamix smoothie if spinach/banana/yogurt present, deterministic). TodayView.swift + TodayViewModel + tests: hero dinner card with why-this disclosure, breakfast/lunch/snack rows, Cook button → CookMode → Feedback, expiring-soon banner with recipe count, snack strip. TodayUITests: cook tonight's dinner and submit feedback for 2 members.",
  "", f"`{V} RasoiTests/QuickSnacksTests RasoiTests/TodayViewModelTests RasoiUITests/TodayUITests` green.")
t("Nutrition dots on Plan + week summary; Insights screen","M9",[len(T)-1],
  "Engines exist. Insights = per child: 5 favourites, 5 'not lately', most-cooked recipes (4 weeks), cuisine variety count, planned-vs-cooked ratio (shown as a neutral count, no judgement).",
  "PlanView day rows get 5 coverage dots with a legend; WeekSummaryCard shows 'This week is light on fruit' style hint (from AppCopy). InsightsView + InsightsViewModel + tests.",
  "No streaks, no scores shown as numbers to kids, no calories (R2/R3).", f"`{V} RasoiTests/InsightsViewModelTests` green.")
t("HUMAN: review nutrition & insights copy","M9",[len(T)-1],
  "R2 compliance depends on wording.",
  "docs/COPY-NUTRITION.md: every nutrition/insight string with the rule it satisfies, plus the MyPlate table used and its source URL.",
  "Do not mark passing.", "FLAG FOR HUMAN REVIEW — Shikher approves docs/COPY-NUTRITION.md.", "HUMAN")
M9_END = len(T)-2

# ---------------- M10 notifications, export, polish
t("NotificationScheduler (shopping-day, cook-tonight, expiring-soon) + tests with injected center","M10",[M9_END, M8_END],
  "SPEC §7. UNUserNotificationCenter behind a protocol so tests inject a fake.",
  "Rasoi/Services/NotificationScheduler.swift + NotificationSchedulerTests (schedules exactly one of each kind; respects master switch and quiet window 21:00–07:00; expiring-soon only when something expires within 1 day; reschedule is idempotent; max pending ≤ 10). NotificationsSettingsView with toggles + times.",
  "No push. Copy in AppCopy.swift.", f"`{V} RasoiTests/NotificationSchedulerTests` green.")
t("Export (JSON share sheet) + Appearance setting","M10",[len(T)-1],
  "Export = all entities as one JSON document via ShareLink; Appearance = system/light/dark.",
  "Rasoi/Services/Exporter.swift + ExporterTests (round-trip decode of the export; counts match). AppearanceView.",
  "No import in v1.", f"`{V} RasoiTests/ExporterTests` green.")
t("Accessibility + Dynamic Type pass","M10",[len(T)-1],
  "SPEC §8: readable at XXL, big kitchen tap targets, VoiceOver labels on icon-only buttons.",
  "Audit every screen: add accessibilityLabel to icon buttons, ensure min 44 pt targets, test layouts at accessibilityExtraLarge in a UI test that walks all 5 tabs without truncated titles. docs/A11Y.md checklist.",
  "", f"`{V} RasoiUITests/AccessibilityUITests` green.")
t("App icon (generated SVG→PNG script) + launch polish + empty states","M10",[len(T)-1],
  "North has scripts/make-app-icon.swift as a pattern.",
  "scripts/make-app-icon.swift drawing a simple saffron pot/leaf glyph → 1024 px PNG into Assets; empty states for Plan (no week yet), Pantry (empty), Shop (no list) with one-tap CTAs.",
  "No mascots, no confetti.", f"`{V} --build-only` green; AppIcon present.")
M10_END = len(T)-1

# ---------------- M11 audit/review/install
t("Privacy & network audit script","M11",[M10_END],
  "R1: the only network-capable code is the MapKit StoreFinder. North has scripts/privacy-audit.sh (otool + grep) as a pattern.",
  "scripts/privacy-audit.sh: greps sources for URLSession|Network.framework|WebKit|Analytics|Firebase|Alamofire and fails on any hit outside Rasoi/Services/StoreFinder.swift (which may contain only MapKit/CoreLocation); otool -L on the built binary lists only Apple frameworks. docs/PRIVACY-AUDIT.md with the output.",
  "", "`bash scripts/privacy-audit.sh` exits 0 and docs/PRIVACY-AUDIT.md exists.")
t("Full SPEC audit: every §4 screen, §5 rule and §11 acceptance line mapped to code + test","M11",[len(T)-1],
  "docs/SPEC.md is the pin.",
  "docs/SPEC-AUDIT.md table: SPEC item → file(s) → test(s) → status. Any gap becomes a fix in this task (general fix) or is listed as an explicit deviation with a reason.",
  "Do not silently drop SPEC items.", f"`{V}` green and docs/SPEC-AUDIT.md has no 'MISSING' rows.")
t("Simulator smoke-run + screenshots of every screen","M11",[len(T)-1],
  "Green tests ≠ working app (North lesson). scripts/screenshots.sh pattern from North.",
  "scripts/screenshots.sh boots the detected simulator, seeds a demo household (2 adults, kids born 2022-03-01 and 2017-06-15), generates a week, builds a list, checks 3 items, cooks one dinner with feedback, and captures Onboarding, Today, Plan, SlotSheet, CookMode, Feedback, Pantry, Shop, Stores/Find, Recipes, RecipeDetail, Insights, Settings into docs/screenshots/. Inspect each PNG for layout bugs (overlaps, truncation, empty views) and fix root causes.",
  "Never commit real household data — demo data only.", "docs/screenshots/ contains ≥13 PNGs and docs/REVIEW.md lists each with 'OK' or the fix made.")
t("HUMAN: final review + free-team install to iPhone","M11",[len(T)-1],
  "All AUTO tasks pass. Install uses the free-team CLI sequence from CLAUDE.md.",
  "Finalize docs/REVIEW.md (what was built, deviations, known gaps, how to run). Then, when Shikher says the phone is cabled: scripts/configure-signing.sh free <TEAM_ID>, xcodebuild -allowProvisioningUpdates …, xcrun devicectl device install app. Log the exact commands in docs/REVIEW.md.",
  "Human-only: plugging in, Trust prompts, Developer Mode, keychain Allow.", "FLAG FOR HUMAN REVIEW — Rasoi launches on the iPhone and Shikher approves docs/REVIEW.md.", "HUMAN")

# ---------------- sanity: no forward deps
for x in T:
    for d in x["depends_on"]:
        assert int(d) < int(x["id"]), (x["id"], d)

prd = dict(project="Rasoi — family kitchen planner (iOS)", completion_promise=PROMISE, verify_command=V, spec="docs/SPEC.md",
  forbidden_autonomous_actions=[
    "any network code other than MapKit/CoreLocation inside Rasoi/Services/StoreFinder.swift (R1)",
    "adding third-party dependencies, targets, extensions, entitlements",
    "sending household data off-device; committing real family data (demo data only in screenshots/fixtures)",
    "deleting user data, feedback history or pantry outside the explicit Delete-all-data flow",
    "hand-editing the .xcodeproj (XcodeGen only)",
    "showing calories, weight, or diet-restriction language anywhere (R2)",
    "pushing to main or merging HUMAN-gated work",
    "committing secrets or a real Apple team ID"],
  tasks=[dict(id=x["id"], title=x["title"], milestone=x["milestone"], depends_on=x["depends_on"], verify=x["done"], gate=x["gate"], passes=False) for x in T])
json.dump(prd, open("prd.json","w"), indent=2, ensure_ascii=False)

out = [f"# Rasoi — Build Plan\n\n> Completion promise: {PROMISE}\n> Generated by autonomous-build-orchestrator. Master narrative for humans; the agent executes from prd.json. **docs/SPEC.md is the pin.**\n",
"## Buildable-System Extraction\nA private, local-first SwiftUI/SwiftData iPhone app (SPEC mode, from docs/SPEC.md) for one vegetarian family of four: household + diet settings, a seeded catalog of 185 ingredients and 51 kid-tested vegetarian recipes, pantry tracking with shelf life, a deterministic weekly meal planner that learns from per-child meal feedback, a grocery list grouped by store that restocks the pantry when checked, a MapKit store finder, MyPlate-style coverage dots, local notifications. No AI, no photo recognition, no sync in v1 (Phase 2).\n",
"## Architecture Decision\n- Stack: SwiftUI + SwiftData + MapKit + UserNotifications, iOS 26, XcodeGen-generated project, zero dependencies — identical to North so the verify/install pipeline and skills carry over unchanged.\n- Diagram:\n```\nViews (5 tabs) → ViewModels (per feature) → Engines (pure Swift: AgeBand, DietFilter, KidScore, MealPlanner,\n  GroceryBuilder, PantryDepletion, Units, ShelfLife, NutritionCoverage, QuickSnacks, Scaling)\n                                          → SwiftData (HouseholdMember, DietProfile, Store, Ingredient, PantryItem,\n                                             Recipe, MealPlan/Slot/Feedback, GroceryList/Item, AppSettings)\nServices: SeedImporter (bundled JSON) · StoreFinder (MapKit, the ONLY network path) · NotificationScheduler · Exporter\n```\n- Data model: SPEC §3.\n- Verification strategy: TDD pairs (tests task precedes implementation task) for every engine and view model; UI tests per tab; `bash scripts/verify.sh` = xcodegen → build → full XCTest suite on an auto-detected simulator; privacy audit script; simulator smoke-run with screenshots; HUMAN gates for seed content, copy, MapKit privacy, final install.\n- Verify command: `bash scripts/verify.sh` (`--unit`, `--build-only`, or `RasoiTests/SomeTests` to scope).\n- External boundaries never crossed autonomously: see prd.json forbidden_autonomous_actions.\n",
"## Milestones\n" + "\n".join(f"- {k} — {v} ({sum(1 for x in T if x['milestone']==k)} tasks)" for k,v in MS.items()) + "\n",
"## Task Backlog\n"]
for x in T:
    out.append(f"### TASK {x['id']} — {x['title']}\n- Milestone: {x['milestone']} — {MS[x['milestone']]}\n- Depends on: {', '.join(x['depends_on']) or 'none'}\n- Context: {x['context']}\n- Do: {x['do']}\n- Constraints / Do NOT: {x['dont'] or '—'}\n- Done-check: {x['done']}\n- Review gate: {'HUMAN-REVIEW-REQUIRED' if x['gate']=='HUMAN' else 'AUTO'}\n")
out.append("## Human-review gates\n" + "\n".join(f"- TASK {x['id']} — {x['title']}" for x in T if x["gate"]=="HUMAN") + "\n\nWhy: seed food content and nutrition/feedback wording are advice-adjacent (R2/R3); the MapKit path is the only data leaving the device (R1); the final install is irreversible on the phone.\n")
open("plan.md","w").write("\n".join(out))
print(f"tasks={len(T)} human={sum(x['gate']=='HUMAN' for x in T)}")
