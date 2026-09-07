# The MapKit path (task 053 — HUMAN gate)

Rasoi makes **no network requests at all** except the one described here (SPEC R1). Approve this
document once you have seen real results for 07302 in the simulator, by replying
**approved: task 053**.

## Where the code lives

Everything network-capable is in one file: `Rasoi/Services/StoreFinder.swift`. It is reachable
from exactly one place in the UI — **More › Stores › + › Find nearby**
(`Rasoi/Features/Stores/FindStoresSheet.swift`) — and only when the household taps **Search**.
Nothing runs on launch, in the background, or on a timer. `scripts/audit-privacy.sh` (task 063)
fails the build if any other file imports a network framework.

## What leaves the device, and when

| When | What is sent | To whom |
|---|---|---|
| The household taps **Search** in Find nearby | The **zip code** as text (e.g. "07302"), via `CLGeocoder.geocodeAddressString` | Apple |
| Immediately after, five times | One **search string** — `grocery`, `supermarket`, `Indian grocery`, `Spanish grocery`, `Asian grocery` — plus a **map region** centred on the coordinate that zip code resolved to, spanning 8 km, via `MKLocalSearch` | Apple |

That is the complete list. Specifically, none of the following is ever sent anywhere:

- family members, ages, names, likes or dislikes
- the meal plan, any recipe, any feedback a child gave
- the pantry, the grocery list, or what was bought
- device identifiers, an account (there is none), or analytics of any kind

There is no `URLSession` anywhere in the app, no third-party SDK, no crash reporter and no
telemetry. Apple sees a zip code and five ordinary grocery searches, exactly as if the household
had typed them into Maps.

## Location permission

Rasoi never asks for location on launch. The zip code alone drives the search, so the permission
prompt is not needed for this feature to work. The Info.plist string is present for a future
"use my current location" affordance and reads:

> Rasoi can use your location only to find grocery stores near you when you tap Find nearby.
> Typing a zip code works without it. Nothing is stored or shared.

## What is stored, and when

Nothing from a search is written to the database until the household taps **Add** on a specific
result. That writes one `Store` row containing the shop's name, its postal address, its
coordinate, and the kind Rasoi guessed from the name (Indian grocery, warehouse club, and so on).
Results the household does not add are discarded when the sheet closes.

The kind guess is a keyword match on the shop's name and the search that found it
(`StoreSearch.inferKind`) — for example "Patel Brothers" → Indian grocery, "Costco" → warehouse.
It only decides which aisles that shop is assumed to carry on the shopping list, and the household
can change it on the store's edit screen.

## How to check it yourself

1. Run the app in the simulator, go to **More › Stores › + › Find nearby**.
2. The zip code is prefilled from Diet & Kitchen (07302 by default). Tap **Search**.
3. Real Jersey City shops should appear, nearest first, each with a kind and a distance.
4. Tap **Add** on one; it appears in the store list with its address. Close the sheet — nothing
   else was saved.

## Related code

- `Rasoi/Services/StoreFinder.swift` — the protocol, the MapKit implementation, and the pure
  helpers (queries, radius, deduplication, kind inference).
- `RasoiTests/StoreFinderTests.swift` — 11 tests, all through a fake; the suite never touches the
  network.
