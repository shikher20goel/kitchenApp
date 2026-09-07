import Foundation

/// Every user-facing sentence in settings, about, feedback and nutrition lives here so it can be
/// read in one place at the human copy gates (tasks 043 and 058).
///
/// House rules for this file:
/// - Warm and plain. No marketing, no exclamation marks, no streaks or scores.
/// - Never shames a child or a cook: a meal that did not land is "not today" (SPEC R3).
/// - Never mentions calories, weight, BMI, dieting or restriction (SPEC R2).
enum AppCopy {

    // MARK: - About

    static let appTagline = "A quiet kitchen planner for your family."

    /// SPEC R2 — shown verbatim in About and in Insights.
    static let notNutritionAdviceNote = """
    Rasoi is a planning tool, not nutrition advice. It shows which food groups a day covers so you \
    can see the shape of the week. For questions about how your child is growing or eating, talk \
    to your paediatrician.
    """

    static let privacyNote = """
    Everything stays on this iPhone. There is no account, no sync and no analytics, and Rasoi \
    makes no network requests — the one exception is the store finder, which asks Apple Maps for \
    shops near a zip code only when you tap Find nearby.
    """

    static let vegetarianOnlyNote = "This version plans vegetarian meals only."

    static let zipCodePrivacyNote = """
    Used only to centre a store search when you tap Find nearby. It is never sent anywhere else.
    """

    // MARK: - Feedback (shown after a meal is cooked)

    static let feedbackTitle = "How did it go?"

    /// The three buttons, in order. `MealReaction.label` reads these, so the wording a child could
    /// see exists in exactly one place (R3).
    static let reactionAteAll = "Ate it all"
    static let reactionAteSome = "Ate some"
    static let reactionNotToday = "Not today"

    static let feedbackPrompt = """
    Tap what happened for each person. Skip anyone you did not get to ask — Rasoi only learns \
    from what you tell it.
    """

    static let feedbackNotePlaceholder = "Anything worth remembering?"

    static let feedbackFooter = """
    This is how Rasoi learns what works at your table. It is never a score, and nothing here is \
    shown to your children.
    """

    // MARK: - Data

    static let deleteAllDataTitle = "Delete all data"

    static let deleteAllDataExplanation = """
    This clears your family, pantry, plans, meal history and shopping lists from this iPhone. The \
    recipe and ingredient catalog is put back the way it shipped. There is no copy anywhere else, \
    so this cannot be undone.
    """

    static let deleteAllDataConfirm = "Delete everything"

    static let exportNote = """
    Saves a JSON file of your household, pantry, plans and meal history so you can keep it \
    somewhere yourself. Nothing is uploaded.
    """
}
