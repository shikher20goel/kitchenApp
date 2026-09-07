import Foundation

/// Reads the bundled catalog. The files are resources of the app target, so tests reach them
/// through the same bundle the app does.
enum SeedLoader {
    enum SeedError: LocalizedError {
        case missingFile(String)
        case unreadable(String, underlying: Error)

        var errorDescription: String? {
            switch self {
            case .missingFile(let name):
                return "The seed file \(name) is missing from the app bundle."
            case .unreadable(let name, let underlying):
                return "The seed file \(name) could not be read: \(underlying.localizedDescription)"
            }
        }
    }

    static let ingredientsFileName = "ingredients"
    static let recipesFileName = "recipes"

    static func loadIngredients(from bundle: Bundle = .main) throws -> IngredientSeedFile {
        try load(IngredientSeedFile.self, named: ingredientsFileName, from: bundle)
    }

    static func loadRecipes(from bundle: Bundle = .main) throws -> RecipeSeedFile {
        try load(RecipeSeedFile.self, named: recipesFileName, from: bundle)
    }

    private static func load<T: Decodable>(_ type: T.Type, named name: String, from bundle: Bundle) throws -> T {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw SeedError.missingFile("\(name).json")
        }
        do {
            return try JSONDecoder().decode(T.self, from: try Data(contentsOf: url))
        } catch {
            throw SeedError.unreadable("\(name).json", underlying: error)
        }
    }
}
