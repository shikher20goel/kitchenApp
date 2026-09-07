# Rasoi — Product Specification (v1)

**Rasoi** ("kitchen" in Hindi) is a private, local-first, iPhone-first family kitchen planner.
One household: Shikher, his wife, a 4-year-old and a 9-year-old. Device: iPhone 14 Pro, iOS 26.
Signing: free Apple personal team. Repo: github.com/shikher20goel/kitchenApp (private).
Philosophy: **Healthy first. Kids decide what works. The pantry drives the plan. The plan drives the
list. One weekly shop, zero guesswork on weeknights.**

Bundle ID: `com.shikhergoel.rasoi` · App name: **Rasoi** · Single app target, no extensions.
(Rename = one line in `project.yml` + `Theme.swift` app title; nothing else depends on the name.)

---

## 1. Red lines (never violate)

- R1. **No network code except Apple MapKit local search** for the store finder (task-scoped,
  user-initiated, only sends a search string + zip-code coordinate to Apple). No URLSession, no
  analytics, no third-party SDKs, no AI/LLM calls in v1. Verified by audit task 063.
- R2. **No diet or medical claims.** Nutrition guidance is limited to USDA MyPlate food-group
  counts (fruit, vegetables, grains, protein foods, dairy) per age band. Never mention calories,
  weight, BMI, "losing"/"gaining", or restriction for any family member. Settings carries a plain
  note: Rasoi is a planning tool, not nutrition advice; consult a paediatrician for diet questions.
- R3. **Never shame a child.** A refused meal is logged as "not today", never "failed", never a red
  mark. Copy stays warm and neutral. No streaks, no scores shown to kids.
- R4. **Vegetarian is a hard filter.** The seeded catalog contains zero meat, poultry, fish or
  gelatin. Egg-containing recipes are hidden unless `eggsOK` is on. User-excluded ingredients are
  hidden everywhere (planner, suggestions, search).
- R5. **Planner is deterministic and explainable.** Every planned meal can show "why this":
  the rule(s) that chose it (pantry match, kid score, variety, quick weekday). No randomness
  without a seed; tests reproduce plans exactly.
- R6. **Household data is sacred.** Feedback history and pantry are never bulk-deleted except via
  explicit "Delete all data" (double-confirm). Seed re-runs are idempotent.
- R7. Free-team constraints: no iCloud/CloudKit, no push, no App Groups, no restricted
  entitlements, single app target. Location permission is optional (zip code works without it).

## 2. Stack

SwiftUI + SwiftData (iOS 26.0 min), MapKit (`MKLocalSearch` + `CLGeocoder` for zip → coordinate),
UserNotifications (local: shopping-day reminder, cook-tonight reminder), XCTest. Project generated
by XcodeGen from `project.yml` (never hand-edit the .xcodeproj). Zero external dependencies.
Repo layout: `Rasoi/` (sources), `RasoiTests/`, `RasoiUITests/`, `project.yml`, `scripts/verify.sh`,
`scripts/configure-signing.sh`, `docs/`, `seed/` (recipes.json, ingredients.json — bundled as
resources of the app target and read by tests).

Architecture: MVVM-lite exactly as North — Views → ViewModels → pure-Swift **Engines** → SwiftData.
All planning/scoring/list-building logic lives in `Rasoi/Engines/` as pure functions over plain
structs so it is unit-testable without SwiftData.

## 3. Data model (SwiftData entities)

- **HouseholdMember**: name, dateOfBirth, role (`adult`|`child`), likes [String], dislikes
  [String], avatarSymbol, colorHex, sortOrder, isActive. Age band computed: `preschool` (2–5),
  `child` (6–8), `preteen` (9–13), `teen` (14–18), `adult`.
- **DietProfile** (singleton): isVegetarian (default true, locked on in v1), eggsOK (default
  true), dairyOK (true), nutFree (false), glutenFree (false), excludedIngredients [String],
  preferredCuisines [String] (default: Indian, Mexican, Italian, Chinese-style, American),
  appliances [String] (default: instantPot, vitamix, stovetop, oven; options also airFryer,
  microwave, blenderBasic), zipCode (default "07302"), shoppingWeekday (default Sunday),
  weekdayMaxCookMinutes (default 35), hasCompletedOnboarding, seedVersion.
- **Store**: name, kind (`supermarket`|`warehouse`|`indian`|`hispanic`|`eastAsian`|`farmers`|
  `other`), address, latitude, longitude, isPreferred, sortOrder, categoryAffinity [String]
  (ingredient categories normally bought here, e.g. indian → legumes, spices, atta, paneer).
  Default seed (editable, no coordinates until the user confirms via finder): Walmart
  (supermarket), Costco (warehouse), Stop & Shop (supermarket), "Indian grocery" (indian),
  "Spanish grocery" (hispanic), "Chinese grocery" (eastAsian).
- **Ingredient** (seeded catalog, ~185 rows from `seed/ingredients.json`): name, aliases [String],
  category (`fruit`|`vegetable`|`leafyGreen`|`dairy`|`egg`|`legume`|`grain`|`flourBread`|`nutSeed`|
  `spice`|`oilCondiment`|`frozen`|`snack`|`beverage`|`other`), defaultUnit, typicalShelfLifeDays,
  isStaple (bought every week regardless of plan), defaultStoreKind, nutritionTags [String]
  (`protein`, `iron`, `calcium`, `fibre`, `vitaminC`, `vitaminA`, `wholeGrain`, `healthyFat`),
  containsEgg, containsDairy, containsNuts, containsGluten, isQuickHealthySnack (apple, banana,
  cucumber, roasted chana, yogurt…).
- **PantryItem**: ingredient→Ingredient, quantity, unit, location (`fridge`|`pantry`|`freezer`),
  addedAt, expiresAt? (addedAt + shelf life by default), lowThreshold?, source (`manual`|`shop`|
  `seed`). Unique per ingredient+location.
- **Recipe** (seeded 51 from `seed/recipes.json`, plus user-created): title, cuisine, mealTypes
  [`breakfast`|`lunch`|`dinner`|`snack`], appliances [String], prepMinutes, cookMinutes,
  servings, minAgeYears, ingredients [RecipeIngredient: ingredientName, quantity, unit, isOptional,
  note], steps [String], nutritionTags [String], containsEgg/Dairy/Nuts/Gluten, isQuick
  (total ≤ 15 min), kidBaseline (1–5 editorial "kids usually like this"), isFavorite, isHidden,
  source (`seed`|`user`), seedID (stable key for idempotent reseed), lunchboxOK.
- **MealPlan**: weekStart (Monday, unique); **MealSlot**: plan→MealPlan, date, mealType,
  recipe→Recipe?, servings, status (`planned`|`cooked`|`skipped`|`eatingOut`), reasons [String]
  (explainability), lockedByUser. Unique per date+mealType.
- **MealFeedback**: slot→MealSlot, member→HouseholdMember, reaction (`ateAll`|`ateSome`|
  `notToday`), note?, createdAt. Unique per slot+member.
- **GroceryList**: weekStart (unique), generatedAt, isFinalized; **GroceryItem**: list→GroceryList,
  ingredient→Ingredient, quantity, unit, store→Store?, isChecked, checkedAt?, neededFor [String]
  (recipe titles), isStapleTopUp, addedManually.
- **AppSettings** (singleton): shoppingReminderEnabled/time (default Sat 18:00), cookReminderEnabled/
  time (default 16:30), notificationsMasterSwitch, appearance.

Analytics (kid scores, nutrition gaps) are **computed, never stored**.

## 4. Screens & navigation

Tab bar: **Today · Plan · Pantry · Shop · More**.

1. **Today** — date + "Tonight: <dinner>" hero card (photo-less, icon + cuisine chip, total time,
   "why this" disclosure); breakfast/lunch/snack rows; **Cook** button opens recipe steps in a
   large-type step-by-step view (one step per screen, swipe, keep-awake); after cooking →
   **Feedback sheet**: per family member three big buttons (Ate it all / Ate some / Not today) +
   optional note; **Quick healthy snack** strip: 3 suggestions from pantry items tagged
   isQuickHealthySnack (apple, banana + yogurt, spinach-banana Vitamix smoothie…).
   Expiring-soon banner if any pantry item expires within 2 days ("Use the spinach: 2 recipes").
2. **Plan** — 7-day grid (Mon–Sun) × 4 meals; **Generate week** (or Regenerate unlocked slots);
   tap a slot → swap sheet listing alternatives ranked with reasons; long-press → lock/skip/
   eating out; per-day nutrition dots (fruit/veg/protein/wholegrain/dairy covered or not).
   Week summary card: MyPlate coverage per child (see §6), "3 kid favourites, 2 new recipes".
3. **Pantry** — segmented Fridge / Pantry / Freezer; search-add from the ingredient catalog
   (type-ahead with aliases, e.g. "toor" → Toor dal); quantity steppers; expiring-soon sort;
   "Mark used" and "Ran out" swipe actions; **Restock from list** happens automatically when
   items are checked in Shop. (Photo scan = Phase 2; a disabled "Scan fridge" button with a
   "coming later" tooltip is allowed.)
4. **Shop** — the current week's grocery list grouped **by store** (sections in store sortOrder),
   then by ingredient category; check-off with haptic; checked items move to pantry with
   shelf-life-based expiry; "Why?" shows which recipes need it; add-manual row; share as text;
   **Build list** from the plan (idempotent: re-running merges, never duplicates, never unchecks).
5. **More** — Family (members, DOB, likes/dislikes); Diet & Kitchen (toggles, excluded
   ingredients, appliances, cuisines, weekday max cook time); Stores (list + **Find nearby**:
   zip → `CLGeocoder` → `MKLocalSearch` with queries "grocery", "supermarket", "Indian grocery",
   "Spanish grocery", "Asian grocery" within 8 km; user taps to add; nothing is stored until
   tapped); Recipes (browse/filter/search seeded + user recipes, add/edit, favourite, hide);
   Insights (per-child favourites/least-liked, most-cooked, variety over 4 weeks);
   Notifications; Appearance; the R2 note; Export (JSON share sheet); Delete all data.
6. **Onboarding** (first launch, ≤2 min): family members + DOB → diet toggles → appliances →
   zip code + pick stores → "Generate my first week".

## 5. Engines (pure Swift, deterministic, fully unit-tested)

- **AgeBand**: DOB → band on a given date.
- **DietFilter**: recipe eligible iff vegetarian, egg/dairy/nut/gluten flags respect profile,
  no ingredient in excludedIngredients (alias-aware), minAge ≤ youngest member at the table for
  dinner/lunch (breakfast/snack may be per-member), required appliances ⊆ profile.appliances.
- **KidScore**: per recipe per child from MealFeedback: ateAll=+1, ateSome=+0.4, notToday=−1,
  exponentially decayed (half-life 60 days), blended with kidBaseline when n<3:
  `score = (n/(n+3))·feedbackMean + (3/(n+3))·(kidBaseline−3)/2`. Household kid score = mean over
  children present. A recipe with ≥3 consecutive notToday from every child is "resting" for 30 days.
- **MealPlanner**: fills unlocked slots for the week. Inputs: eligible recipes, pantry, kid
  scores, history (last 21 days). Rules in priority order, each producing a reason string:
  1. No recipe repeats within 3 days; same primary cuisine not on consecutive dinners.
  2. Weekday dinner total time ≤ weekdayMaxCookMinutes; weekend may exceed.
  3. Prefer recipes whose ingredients are ≥60 % in pantry (pantry-first), then those using
     items expiring within 3 days (use-it-up).
  4. Rank by household kid score; guarantee ≥2 "sure-thing" dinners (score ≥0.6) per week and
     ≤2 "new" (n=0) recipes per week.
  5. Nutrition balance: across the week ensure each day has ≥1 fruit slot, ≥2 vegetable-tagged
     recipes, ≥1 legume/paneer/egg/dairy protein at lunch+dinner, ≥1 wholeGrain.
  6. Breakfast pool rotates ≥4 distinct breakfasts per week; snack slot defaults to fruit +
     one prepared snack.
  Deterministic tie-break: seedID ascending. Output includes a `PlanExplanation` per slot.
- **GroceryBuilder**: sum RecipeIngredient quantities across planned, un-cooked slots scaled by
  servings ÷ recipe.servings → normalise units (g/kg, ml/l, count, cup→ml table) → subtract
  pantry quantities → add staples (isStaple) not in pantry or below lowThreshold → assign store:
  a preferred Store whose categoryAffinity contains the ingredient category, else the first
  preferred supermarket/warehouse, else "Any store". Merge into existing list idempotently.
- **PantryDepletion**: marking a slot cooked decrements pantry by scaled recipe quantities
  (floor at 0, remove at 0 unless staple).
- **NutritionCoverage**: per child per day, count food-group hits from the recipes' ingredient
  categories/nutritionTags vs MyPlate targets for the age band (4–8: fruit 1–1.5 cups, veg 1.5
  cups, grains 5 oz-eq, protein 4 oz-eq, dairy 2.5 cups; 9–13: fruit 1.5 cups, veg 2–2.5 cups,
  grains 5–6 oz-eq, protein 5 oz-eq, dairy 3 cups). v1 shows **coverage dots** (group present in
  the day's plan or not) and a weekly "light on X" hint — never quantities per child, never
  calories (R2).
- **ShelfLife**: expiry defaults from ingredient.typicalShelfLifeDays by location (freezer ×6).
- **StoreFinder** (thin MapKit wrapper behind a protocol so tests inject fake results).

## 6. Seed content (bundled JSON, HUMAN-reviewed at task 020)

- `seed/ingredients.json` ~185 ingredients across Indian staples (toor/moong/masoor/chana/urad
  dal, rajma, chole, paneer, atta, besan, poha, sooji, rice varieties, spices), everyday produce,
  fruit, dairy, eggs, tofu, frozen veg, pasta, tortillas, oats, quinoa, nuts/seeds, snacks.
- `seed/recipes.json` 51 recipes, all vegetarian, ~35 % Indian and the rest Mexican / Italian /
  Chinese-style / American / Mediterranean, each tagged for Instant Pot / Vitamix / stovetop /
  oven, with steps, ingredients, nutritionTags, minAge, kidBaseline. Breakfast ≥10, lunch/dinner
  ≥30 (≥12 Instant Pot, ≥8 ≤15-min), snacks/smoothies ≥8 (≥5 Vitamix). Every recipe has a
  "make it kid-friendly" note (mild spice, serve with yogurt, cut small). Egg recipes ≤5,
  flagged. Authored by the orchestrator, listed in docs/SEED-RECIPES.md for the human gate.

## 7. Notifications (local, optional, default ON only for the shopping reminder)

Shopping-day reminder (Sat 18:00 default: "Tomorrow's list has N items across M stores");
cook-tonight reminder (16:30: "Tonight: <recipe>, <total> min"); expiring-soon (morning, only if
something expires today/tomorrow). Respect a quiet window; max 1 of each per day; never nag.

## 8. Design language

Warm, clean, Apple-native: system fonts, SF Symbols, generous whitespace, soft palette (saffron
accent, sage, cream; dark mode supported), big tap targets for one-handed kitchen use, cook mode
readable from 1 m away (Dynamic Type XXL), subtle haptics. No mascots, no confetti, no badges.

## 9. Out of scope for v1 (do not build)

Photo/AI recognition of fridge or pantry, LLM recipe generation, barcode scanning, price
tracking, online ordering, CloudKit/any sync, widgets, Apple Watch, HealthKit, kids' education/
games content, calorie counting, App Store prep. The loop must not add these even if "easy".

## 10. Phase 2 (separate backlog)

Fridge/pantry photo scan via Claude API vision (key in Keychain, explicit tap, only the photo is
sent) → AI "what can I make" and new-recipe suggestions → barcode add → paid team: family sync
via CloudKit, widgets, no weekly reinstall.

## 11. Acceptance snapshot (v1 done means)

Onboarding <2 min; generate a full 7-day plan in <1 s on device with every slot explainable;
grocery list for that plan grouped by store in one tap; checking items restocks pantry; cooking
decrements pantry; feedback in ≤3 taps per family member; kid scores visibly reorder the next
plan (tested); store finder returns real results for 07302; 50 seed recipes load idempotently and
pass diet filters; verify.sh green; simulator smoke-run screenshots reviewed; all HUMAN gates
approved.
