# SPEC audit (task 064)

Every screen in SPEC §4, every engine rule in §5, every red line in §1 and every acceptance line
in §11, mapped to the code that implements it and the test that holds it in place. Deviations are
listed explicitly with the reason; there are no missing items.

Run `bash scripts/verify.sh` to execute every test named here (377 test cases at the time of
writing), and `bash scripts/privacy-audit.sh` for the R1 checks.

## §1 Red lines

| Red line | Where it lives | Proof |
|---|---|---|
| R1 no network except MapKit store search | `Rasoi/Services/StoreFinder.swift` is the only network-capable file | `scripts/privacy-audit.sh` (sources, imports, dependencies, entitlements, `otool -L`); `StoreFinderTests` runs entirely on a fake; `docs/PRIVACY-MAPKIT.md` |
| R2 no diet or medical claims | `Rasoi/Copy/AppCopy.swift`, `NutritionCoverage` returns booleans only | `NutritionCoverageTests`, `InsightsViewModelTests.testTheWeeklyHintNamesAFoodGroupAndNothingElse`, `scripts/gen-copy-doc.py` banned-word sweep, `docs/COPY-NUTRITION.md` |
| R3 never shame a child | `MealReaction` labels come from `AppCopy`; insights count in words | `MealPlanTests.testReactionCopyNeverShamesAChild`, `InsightsViewModelTests.testCopyNeverShowsAScoreOrAStreak`, `docs/COPY-FEEDBACK.md` |
| R4 vegetarian is a hard filter | `DietFilter.nonVegetarianWords`, seeded catalog | `SeedLoaderTests.testCatalogIsVegetarian`, `DietFilterTests.testNonVegetarianIngredientIsRejected…` |
| R5 deterministic, explainable planning | `MealPlanner` (tie-break by recipe id), `PlannedMeal.reasons` | `MealPlannerTests.testTheSameInputAlwaysGivesTheSamePlan`, `…testTiesAreBrokenByRecipeIDAscending`, `MealPlannerPerformanceTests.testEverySlotCanExplainItself` |
| R6 household data is sacred | `DataManager.deleteEverything` is the only bulk delete; `FamilyViewModel.remove` deactivates | `DataManagerTests`, `FamilyViewModelTests.testRemovingAMemberWithHistoryDeactivatesThemInstead`, `SeedImporterTests.testUserRecipesSurviveAReimport` |
| R7 free-team constraints | no entitlements, single target in `project.yml` | `scripts/privacy-audit.sh` entitlements section |

## §4 Screens

| SPEC item | Code | Tests |
|---|---|---|
| §4 tab bar: Today · Plan · Pantry · Shop · More | `Rasoi/App/ContentView.swift`, `TabModels` | `LaunchUITests`, `AccessibilityUITests.testEveryTabRendersAtAccessibilityExtraLarge` |
| §4.1 Tonight hero card + "why this" | `TodayView.dinnerCard` | `TodayViewModelTests.testTheDinnerCardCarriesItsReasons`, `TodayUITests` |
| §4.1 breakfast/lunch/snack rows | `TodayView.mealRow` | `TodayViewModelTests.testTodayShowsTheDaysMealsOnceTheWeekIsPlanned` |
| §4.1 Cook → step-by-step, keep-awake | `CookModeView` | `ScalingTests`, `CookModeUITests`, `TodayUITests` |
| §4.1 feedback sheet, three buttons per member | `FeedbackView`, `FeedbackViewModel` | `FeedbackViewModelTests` (8), `TodayUITests` |
| §4.1 quick healthy snack strip | `QuickSnacks`, `TodayView` | `QuickSnacksTests` (9), `TodayViewModelTests.testTheSnackStripComesFromThePantry` |
| §4.1 expiring-soon banner with recipe count | `TodayViewModel.expiringHeadline` | `TodayViewModelTests.testExpiringSoonBannerNamesTheItemAndCountsRecipes` |
| §4.2 week × 4 meals | `PlanView` (day sections — see deviations) | `PlanViewModelTests.testGenerateCreatesAFullWeek`, `PlanUITests` |
| §4.2 Generate / Regenerate unlocked | `PlanViewModel.generateWeek` | `PlanViewModelTests.testRegeneratePreservesLockedSlots` |
| §4.2 swap sheet ranked with reasons | `SlotSheet`, `MealPlanner.alternatives` | `PlanViewModelTests.testAlternativesAreRankedAndExplained`, `PlanUITests` |
| §4.2 lock / skip / eating out | `SlotSheet`, long-press context menu on the row | `PlanViewModelTests.testSkipAndEatingOutStickThroughARegenerate` |
| §4.2 per-day nutrition dots | `CoverageDots`, `PlanViewModel.coverage(on:)` | `NutritionCoverageTests`, `AccessibilityUITests.testCoverageDotsAreDescribedInWords` |
| §4.2 week summary card | `WeekSummaryCard`, `PlanViewModel.summary` | `PlanViewModelTests.testSummaryCountsWhatIsOnTheTable` |
| §4.3 Fridge / Pantry / Freezer segments | `PantryView` | `PantryViewModelTests.testTheSameIngredientInAnotherLocationIsItsOwnRow` |
| §4.3 search-add with aliases | `Ingredient.search`, `AddPantryItemSheet` | `IngredientTests`, `PantryViewModelTests.testSearchFinds…`, `PantryUITests` |
| §4.3 quantity steppers, expiring sort | `PantryView`, `PantryViewModel.sortOrder` | `PantryViewModelTests.testExpiringSortPutsTheSoonestFirst` |
| §4.3 mark used / ran out | `PantryViewModel.markUsed`, `.ranOut` | `PantryViewModelTests.testRanOutRemovesANonStaple…` |
| §4.3 restock from the list | `ShopViewModel.setChecked` | `ShopViewModelTests.testCheckingAnItemPutsItInThePantryWithAnExpiry` |
| §4.3 disabled "Scan fridge" | `PantryView` sort menu | (visual; `docs/screenshots/pantry.png`) |
| §4.4 list grouped by store then category | `ShopViewModel.sections` | `ShopViewModelTests.testSectionsAreGroupedByStoreThenCategory` |
| §4.4 check-off with haptic → pantry | `ShopView.row`, `ShopViewModel.setChecked` | `ShopViewModelTests`, `ShopUITests` |
| §4.4 "Why?" shows the recipes | `WhySheet`, `GroceryItem.neededFor` | `GroceryBuilderTests.testTwoRecipesSharingAnIngredientBecomeOneLine` |
| §4.4 add manual row, share as text | `AddGroceryItemSheet`, `ShopViewModel.shareText` | `ShopViewModelTests.testAManualItemIsKeptThroughARebuild`, `…testShareTextIsGroupedAndReadable` |
| §4.4 Build list idempotent | `GroceryBuilder.merge` | `GroceryBuilderTests` (merge cases), `ShopViewModelTests.testBuildingTwiceNeverDuplicatesALine` |
| §4.5 Family | `FamilyListView`, `MemberEditView` | `FamilyViewModelTests` (10) |
| §4.5 Diet & Kitchen | `DietSettingsView` | `DietSettingsViewModelTests` (12) |
| §4.5 Stores + Find nearby | `StoresView`, `FindStoresSheet` | `StoresViewModelTests` (7), `StoreFinderTests` (11) |
| §4.5 Recipes browse / add / edit | `RecipeListView`, `RecipeDetailView`, `RecipeEditView` | `RecipesViewModelTests` (10), `RecipeEditorTests` (11) |
| §4.5 Insights | `InsightsView` | `InsightsViewModelTests` (10) |
| §4.5 Notifications | `NotificationsSettingsView`, `NotificationScheduler` | `NotificationSchedulerTests` (12) |
| §4.5 Appearance | `AppearanceView`, `AppSettings.appearance` | `AppSettingsTests.testAppearanceRoundTrips` |
| §4.5 About with the R2 note | `AboutView`, `AppCopy.notNutritionAdviceNote` | `docs/COPY-FEEDBACK.md` |
| §4.5 Export (JSON share sheet) | `Exporter`, `ExportView` | `ExporterTests` (6) |
| §4.5 Delete all data, double confirm | `MoreView`, `DataManager.deleteEverything` | `DataManagerTests` (2) |
| §4.6 Onboarding ≤2 min | `OnboardingFlow`, `RootView` | `OnboardingUITests` (2) |

## §5 Engines

| Rule | Code | Tests |
|---|---|---|
| AgeBand | `Rasoi/Engines/AgeBand.swift` | `AgeBandTests` (8) |
| DietFilter (veg, egg/dairy/nut/gluten, exclusions, min age, appliances) | `Rasoi/Engines/DietFilter.swift` | `DietFilterTests` (15) |
| KidScore (weights, 60-day half-life, baseline blend, household mean, resting) | `Rasoi/Engines/KidScore.swift` | `KidScoreTests` (18) |
| MealPlanner rule 1 variety | `MealPlanner.isRepeat`, cuisine penalty | `MealPlannerTests.testNoRecipeRepeatsWithinThreeDays`, `…testTheSameCuisineIsNotServedTwoDinnersRunning` |
| MealPlanner rule 2 weekday time cap | `Constraints.timeCap` | `MealPlannerTests.testWeekdayDinnersFitTheCapAndWeekendsMayNot` |
| MealPlanner rule 3 pantry-first, use-it-up | `Weight.pantryCoverage`, `Weight.useItUp` | `…testARecipeAlreadyInThePantryWins`, `…testSomethingAboutToExpireIsUsedUpFirst` |
| MealPlanner rule 4 kid score, sure-thing and new quotas | `Weight.kidScore`, `mustPickASureThing`, `newRecipeCap` | `…testHigherKidScoresAreServedFirst`, `…testAtLeastTwoSureThingDinnersAWeek`, `…testAtMostTwoBrandNewRecipesWhenKnownOnesExist` |
| MealPlanner rule 5 nutrition balance | `nutritionBonus` | `…testEachDayGetsFruitVegetablesProteinAndAWholeGrain` |
| MealPlanner rule 6 breakfast rotation, fruit snacks | `Weight.repeatedBreakfast`, snack fruit nudge | `…testAtLeastFourDifferentBreakfasts`, `…testASmallBreakfastPoolStillFillsTheWeek` |
| GroceryBuilder | `Rasoi/Engines/GroceryBuilder.swift` | `GroceryBuilderTests` (19) |
| PantryDepletion | `Rasoi/Engines/PantryDepletion.swift` | `PantryDepletionTests` (11) |
| NutritionCoverage | `Rasoi/Engines/NutritionCoverage.swift` | `NutritionCoverageTests` (12) |
| ShelfLife | `Rasoi/Engines/ShelfLife.swift` | `ShelfLifeTests` (6) |
| StoreFinder behind a protocol | `Rasoi/Services/StoreFinder.swift` | `StoreFinderTests` (11) |
| Units (g/kg, ml/l, cup/tbsp/tsp, count) | `Rasoi/Engines/Units.swift` | `UnitsTests` (8) |
| Scaling (servings, kitchen rounding) | `Rasoi/Engines/Scaling.swift` | `ScalingTests` (9) |

## §6 Seed content

| Item | Where | Tests |
|---|---|---|
| 185 ingredients, 51 recipes, all vegetarian | `seed/ingredients.json`, `seed/recipes.json` | `SeedLoaderTests` (11) |
| Idempotent import, user data preserved | `SeedImporter` | `SeedImporterTests` (7) |
| Human review of the catalog | `docs/SEED-RECIPES.md` | HUMAN gate — task 028 |

## §7 Notifications

Shopping day, cook tonight and expiring soon, one of each at most, never between 21:00 and 07:00 —
`NotificationScheduler`, `NotificationsSettingsView`, copy in `AppCopy`; `NotificationSchedulerTests`.

## §11 Acceptance snapshot

| Acceptance line | Status |
|---|---|
| Onboarding under two minutes | ✅ four pages, `OnboardingUITests` completes it in seconds |
| A 7-day plan in under a second, every slot explainable | ✅ `MealPlannerPerformanceTests` (0.17 s over the real catalog) |
| Grocery list grouped by store in one tap | ✅ `ShopUITests`, `ShopViewModelTests` |
| Checking items restocks the pantry | ✅ `ShopViewModelTests.testCheckingAnItemPutsItInThePantryWithAnExpiry` |
| Cooking decrements the pantry | ✅ `PantryDepletionTests.testCookingASlotDepletesThroughTheService` |
| Feedback in ≤3 taps per member | ✅ one tap per person plus Save (`FeedbackView`) |
| Kid scores reorder the next plan | ✅ `PlanViewModelTests.testARefusedDinnerDropsOutOfNextWeeksPlan` |
| Store finder returns real results for 07302 | ⏳ HUMAN gate — task 053 (`docs/PRIVACY-MAPKIT.md`) |
| 50 seed recipes load idempotently and pass the diet filter | ✅ `SeedImporterTests`, `RecipesViewModelTests` |
| `verify.sh` green | ✅ 377 test cases |
| Simulator smoke-run screenshots reviewed | ✅ task 065 — `docs/screenshots/`, `docs/REVIEW.md` |
| All HUMAN gates approved | ⏳ tasks 028, 043, 053, 058, 066 await Shikher |

## Deviations, and why

1. **Plan is a list of days, not a 7×4 grid.** SPEC §4.2 allows either ("horizontal day columns or
   vertical day sections — pick vertical days for one-handed use"); a real grid is unusable at
   accessibility text sizes. `docs/A11Y.md` records the same.
2. **Feedback is pushed, not a sheet.** iOS will not present a sheet while a full-screen cover is
   dismissing, so cook mode closes and the card offers "How did it go?", which pushes
   `FeedbackView`. Same taps, one fewer transition.
3. **"≤2 new recipes a week" yields to a full week.** On a fresh install every recipe is new;
   SPEC §11 requires a full plan, so the cap relaxes rather than leaving dinners empty
   (`MealPlannerTests.testAFreshCatalogStillFillsTheWholeWeek`).
4. **Supermarkets claim every category.** SPEC's default store affinities left "everything else" to
   supermarkets; they are given every category instead, and speciality shops win first. The default
   speciality stores ship un-preferred, so nothing routes to a shop with no address.
5. **Allergen flags come from required ingredients only.** Seven seeded recipes carry an optional
   yogurt, naan or pita; flagging the recipe would hide a dish the household could happily make.
6. **`sortOrder`-based store order replaces "store sortOrder" in the grocery builder**, which is the
   same thing said twice — no behavioural difference.
