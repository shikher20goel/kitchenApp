"""Helpers for rewriting seed/recipes.json and seed/ingredients.json in place.

Formatting is preserved byte-for-byte for untouched entries (indent=1, no trailing newline),
so a rewrite of four recipes shows as a diff of four recipes.

Allergen flags are recomputed from the ingredient catalog rather than typed by hand: a recipe
carries a flag when a REQUIRED ingredient carries it (an optional garnish does not).
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RECIPES = ROOT / "seed/recipes.json"
INGREDIENTS = ROOT / "seed/ingredients.json"

FLAGS = ("containsEgg", "containsDairy", "containsNuts", "containsGluten")


def load(path):
    return json.loads(path.read_text())


def save(path, data):
    path.write_text(json.dumps(data, indent=1, ensure_ascii=False))


def catalog():
    return {i["name"]: i for i in load(INGREDIENTS)["ingredients"]}


def add_ingredient(**fields):
    """Adds a catalog row if it is not there yet. Every key the DTO knows must be present."""
    data = load(INGREDIENTS)
    names = {i["name"] for i in data["ingredients"]}
    if fields["name"] in names:
        return False
    row = {
        "name": fields["name"],
        "aliases": fields.get("aliases", []),
        "category": fields["category"],
        "defaultUnit": fields.get("defaultUnit", "g"),
        "typicalShelfLifeDays": fields.get("typicalShelfLifeDays", 365),
        "isStaple": fields.get("isStaple", False),
        "defaultStoreKind": fields.get("defaultStoreKind", "supermarket"),
        "nutritionTags": fields.get("nutritionTags", []),
        "containsEgg": fields.get("containsEgg", False),
        "containsDairy": fields.get("containsDairy", False),
        "containsNuts": fields.get("containsNuts", False),
        "containsGluten": fields.get("containsGluten", False),
        "isQuickHealthySnack": fields.get("isQuickHealthySnack", False),
    }
    if "gramsPerTeaspoon" in fields:
        row["gramsPerTeaspoon"] = fields["gramsPerTeaspoon"]
    data["ingredients"].append(row)
    save(INGREDIENTS, data)
    return True


def line(name, quantity, unit, note="", optional=False):
    return {
        "ingredientName": name,
        "quantity": quantity,
        "unit": unit,
        "isOptional": optional,
        "note": note,
    }


def rewrite(seed_id, *, title=None, ingredients, steps, prep, cook, source_note, source_url,
            kid_note=None, servings=None, min_age=None, tags=None, appliances=None,
            meal_types=None, cuisine=None, lunchbox=None, kid_baseline=None):
    """Replaces one recipe's content, keeping its identity and the household-owned fields."""
    data = load(RECIPES)
    known = catalog()
    for entry in data["recipes"]:
        if entry["seedID"] != seed_id:
            continue

        unknown = [item["ingredientName"] for item in ingredients
                   if item["ingredientName"] not in known]
        if unknown:
            raise SystemExit(f"{seed_id}: ingredients not in the catalog: {unknown}")

        if title:
            entry["title"] = title
        if cuisine:
            entry["cuisine"] = cuisine
        if meal_types:
            entry["mealTypes"] = meal_types
        if appliances is not None:
            entry["appliances"] = appliances
        if servings:
            entry["servings"] = servings
        if min_age is not None:
            entry["minAgeYears"] = min_age
        if tags is not None:
            entry["nutritionTags"] = tags
        if kid_note:
            entry["kidFriendlyNote"] = kid_note
        if lunchbox is not None:
            entry["lunchboxOK"] = lunchbox
        if kid_baseline is not None:
            entry["kidBaseline"] = kid_baseline

        entry["ingredients"] = ingredients
        entry["steps"] = steps
        entry["prepMinutes"] = prep
        entry["cookMinutes"] = cook
        entry["isQuick"] = prep + cook <= 15
        entry["sourceNote"] = source_note
        entry["sourceURL"] = source_url

        for flag in FLAGS:
            entry[flag] = any(
                known[item["ingredientName"]][flag]
                for item in ingredients
                if not item["isOptional"]
            )

        save(RECIPES, data)
        return entry
    raise SystemExit(f"no recipe with seedID {seed_id}")
