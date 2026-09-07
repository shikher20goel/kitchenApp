# Rasoi

**Rasoi** ("kitchen" in Hindi) is a private, local-first family kitchen planner for iPhone. It keeps
the household's diet settings, a seeded catalog of vegetarian recipes and ingredients, and a pantry
with shelf-life tracking, then builds a deterministic weekly meal plan that learns from per-child
meal feedback. The plan becomes a grocery list grouped by store; checking items off restocks the
pantry, and cooking a meal draws it back down. MyPlate-style coverage dots show which food groups a
day covers. Everything stays on the device: there is no account, no analytics and no sync, and the
only network-capable code in the app is Apple's MapKit local search behind the optional "find a
store near me" button.

The app is SwiftUI + SwiftData, iOS 26, a single app target with zero external dependencies. The
Xcode project is **generated** — edit `project.yml` and run `xcodegen generate`; never hand-edit
`Rasoi.xcodeproj`. Product truth lives in `docs/SPEC.md`, the build backlog in `plan.md` and
`prd.json`, and the seeded catalog in `seed/ingredients.json` + `seed/recipes.json`.

## Build & verify

```
bash scripts/verify.sh              # xcodegen generate → build → full test suite
bash scripts/verify.sh --unit       # unit tests only
bash scripts/verify.sh --build-only # generate + build, no tests
bash scripts/verify.sh RasoiTests/FooTests   # scope to one class or method
```

The simulator is auto-detected with `xcrun simctl list devices available` — never hard-coded.

## Install on a device (free Apple team, CLI only)

```
bash scripts/configure-signing.sh free <TEAM_ID>
xcodegen generate
xcodebuild -project Rasoi.xcodeproj -scheme Rasoi -destination 'generic/platform=iOS' \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration DEVELOPMENT_TEAM=<TEAM_ID> \
  CODE_SIGN_STYLE=Automatic -derivedDataPath build/ build
xcrun devicectl list devices
xcrun devicectl device install app --device <UDID> build/Build/Products/Debug-iphoneos/Rasoi.app
```

`connected (no DDI)` from `devicectl` means Developer Mode is off on the iPhone. A free Apple team
signs for 7 days, so the install has to be repeated weekly.

## Layout

```
Rasoi/App        · Rasoi/Design    · Rasoi/Data (models, Persistence, Seed)
Rasoi/Engines    · Rasoi/Services  · Rasoi/Features/<Feature>/  · Rasoi/Copy
RasoiTests · RasoiUITests · docs/ · seed/ · scripts/
```
