import SwiftUI
import PhotosUI
import UIKit
import Combine

// MARK: - App entry point

@main
struct RezeptApp: App {
    @StateObject private var store = RecipeStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(.light)
        }
    }
}

// MARK: - Models

/// A recipe ingredient stores measured quantity, unit and an optional modifier separately.
/// The custom decoder also migrates ingredients saved by earlier app versions.
struct RecipeIngredient: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var quantity: String
    var unit: String
    var modifier: String
    var colorIndex: Int

    init(
        id: UUID = UUID(),
        name: String,
        quantity: String = "",
        unit: String = "",
        modifier: String = "",
        colorIndex: Int = 7
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.modifier = modifier
        self.colorIndex = colorIndex
    }

    /// Combined amount remains available for search and compatibility with existing UI code.
    var amount: String {
        [quantity, unit].filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// Format shown on recipe ingredient pills, e.g. "450 g  Mehl, Type 405".
    var displayText: String {
        let amountText = amount
        let baseText = amountText.isEmpty ? name : "\(amountText)  \(name)"
        return modifier.isEmpty ? baseText : "\(baseText), \(modifier)"
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, quantity, unit, modifier, amount, colorIndex
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Zutat"
        modifier = try container.decodeIfPresent(String.self, forKey: .modifier) ?? ""
        // Missing color values from older saves now default to white (no custom color).
        colorIndex = try container.decodeIfPresent(Int.self, forKey: .colorIndex) ?? 7

        if let savedQuantity = try container.decodeIfPresent(String.self, forKey: .quantity) {
            quantity = savedQuantity
            unit = try container.decodeIfPresent(String.self, forKey: .unit) ?? ""
        } else {
            let legacyAmount = try container.decodeIfPresent(String.self, forKey: .amount) ?? ""
            let parsed = Self.parseLegacyAmount(legacyAmount, ingredientName: name)
            quantity = parsed.quantity
            unit = parsed.unit
            if modifier.isEmpty {
                modifier = parsed.modifier
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(quantity, forKey: .quantity)
        try container.encode(unit, forKey: .unit)
        try container.encode(modifier, forKey: .modifier)
        try container.encode(colorIndex, forKey: .colorIndex)
    }

    private static func parseLegacyAmount(
        _ value: String,
        ingredientName: String
    ) -> (quantity: String, unit: String, modifier: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ("", "", "") }

        let normalized = trimmed.lowercased()
        if ingredientName.localizedCaseInsensitiveCompare("Mehl") == .orderedSame,
           normalized.hasPrefix("t ") {
            let typeValue = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            return ("", "", "T \(typeValue)")
        }

        let legacyUnits: [String] = ["stck", "stück", "prise", "msp", "pck", "kg", "ml", "el", "tl", "g", "l"]
        for unit in legacyUnits {
            let suffix = " " + unit
            if normalized.hasSuffix(suffix) {
                let quantityLength = trimmed.count - suffix.count
                guard quantityLength >= 0 else { continue }
                let splitIndex = trimmed.index(trimmed.startIndex, offsetBy: quantityLength)
                let parsedQuantity = String(trimmed[..<splitIndex])
                let displayUnit = Self.canonicalUnit(unit)
                return (parsedQuantity, displayUnit, "")
            }
        }

        return (trimmed, "", "")
    }

    private static func canonicalUnit(_ unit: String) -> String {
        switch unit {
        case "el": return "EL"
        case "tl": return "TL"
        case "msp": return "Msp"
        case "stck", "stück": return "Stück"
        case "pck": return "Pck"
        case "prise": return "Prise"
        default: return unit
        }
    }
}

struct Recipe: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var imageData: Data?
    var ingredients: [RecipeIngredient]
    var instructions: [String]
    var category: String

    init(
        id: UUID = UUID(),
        title: String,
        imageData: Data? = nil,
        ingredients: [RecipeIngredient] = [],
        instructions: [String] = [],
        category: String = "Sonstiges"
    ) {
        self.id = id
        self.title = title
        self.imageData = imageData
        self.ingredients = ingredients
        self.instructions = instructions
        self.category = category
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, imageData, ingredients, instructions, category
    }

    /// Supports the old app version, where ingredients were saved as [String].
    /// Old recipes are migrated automatically when they are loaded.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Unbenanntes Rezept"
        imageData = try container.decodeIfPresent(Data.self, forKey: .imageData)
        instructions = try container.decodeIfPresent([String].self, forKey: .instructions) ?? []
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? "Sonstiges"

        if let newIngredients = try? container.decode([RecipeIngredient].self, forKey: .ingredients) {
            ingredients = newIngredients
        } else if let oldIngredients = try? container.decode([String].self, forKey: .ingredients) {
            ingredients = oldIngredients.map { RecipeIngredient(name: $0) }
        } else {
            ingredients = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(imageData, forKey: .imageData)
        try container.encode(ingredients, forKey: .ingredients)
        try container.encode(instructions, forKey: .instructions)
        try container.encode(category, forKey: .category)
    }
}

// MARK: - Local data store

@MainActor
final class RecipeStore: ObservableObject {
    @Published var recipes: [Recipe] = [] {
        didSet { save(recipes, forKey: Self.recipesKey) }
    }

    @Published var categories: [String] = RecipeStore.defaultCategories {
        didSet { save(categories, forKey: Self.categoriesKey) }
    }

    @Published var categoryColors: [String: Int] = [:] {
        didSet { save(categoryColors, forKey: Self.categoryColorsKey) }
    }

    /// Explicit recipe membership supports assigning one recipe to multiple categories.
    /// A missing key means the legacy Recipe.category property is used as fallback.
    @Published var categoryRecipeIDs: [String: [UUID]] = [:] {
        didSet { save(categoryRecipeIDs, forKey: Self.categoryRecipeIDsKey) }
    }

    @Published var ingredientCatalog: [String] = RecipeStore.defaultIngredients {
        didSet { save(ingredientCatalog, forKey: Self.ingredientsKey) }
    }

    @Published var ingredientModifiers: [String: [String]] = [:] {
        didSet { save(ingredientModifiers, forKey: Self.ingredientModifiersKey) }
    }

    @Published var ingredientQuantities: [String: [String]] = [:] {
        didSet { save(ingredientQuantities, forKey: Self.ingredientQuantitiesKey) }
    }

    @Published var ingredientUnits: [String: [String]] = [:] {
        didSet { save(ingredientUnits, forKey: Self.ingredientUnitsKey) }
    }

    @Published var ingredientColors: [String: Int] = [:] {
        didSet { save(ingredientColors, forKey: Self.ingredientColorsKey) }
    }

    /// Built-in ingredients removed in the app are hidden on subsequent launches too.
    @Published var hiddenDefaultIngredients: [String] = [] {
        didSet { save(hiddenDefaultIngredients, forKey: Self.hiddenDefaultIngredientsKey) }
    }

    private static let recipesKey = "rezeptapp.recipes.v1"
    private static let categoriesKey = "rezeptapp.categories.v1"
    private static let ingredientsKey = "rezeptapp.ingredientCatalog.v1"
    private static let categoryColorsKey = "rezeptapp.categoryColors.v1"
    private static let categoryRecipeIDsKey = "rezeptapp.categoryRecipeIDs.v1"
    private static let ingredientModifiersKey = "rezeptapp.ingredientModifiers.v1"
    private static let ingredientQuantitiesKey = "rezeptapp.ingredientQuantities.v1"
    private static let ingredientUnitsKey = "rezeptapp.ingredientUnits.v1"
    private static let ingredientColorsKey = "rezeptapp.ingredientColors.v1"
    private static let hiddenDefaultIngredientsKey = "rezeptapp.hiddenDefaultIngredients.v1"
    private static let codeDefinedIngredientNamesKey = "rezeptapp.codeDefinedIngredientNames.v1"

    static let defaultCategories = [
        "Hefeteig", "Rührkuchen", "Tarte", "Muffins", "Kekse", "Torten",
        "Plunder", "Tartelette", "Weihnachten", "Cremes", "No-Bake",
        "Blätterteig", "Pralinen", "Sonstiges"
    ]

    static let defaultIngredients = IngredientCatalog.definitions.map { $0.name }

    /// Namen aus der älteren fest eingebauten Liste. Beim Laden werden diese
    /// alten Einträge durch die aktuelle IngredientCatalog.swift ersetzt.
    // Bereits normalisierte Namen vermeiden eine komplexe .map()-Typinferenz
    // an dieser Stelle (Swift Preview Compiler).
    private static let legacyBuiltInIngredientNames: Set<String> = Set<String>([
        "mehl", "zucker", "butter", "ei", "milch", "salz", "zimt",
        "vanillezucker", "wasser", "brauner zucker", "apfel", "zitronensaft",
        "vanille", "blaubeeren", "hefe", "puderzucker", "mandeln", "zartbitter",
        "vollmilch", "saft", "sahne", "mascarpone", "joghurt", "magerquark",
        "himbeeren", "buttermilch", "eigelb", "espresso", "nougat", "haferkekse",
        "marmelade", "biskuit"
    ])

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.recipesKey),
           let savedRecipes = try? JSONDecoder().decode([Recipe].self, from: data) {
            recipes = savedRecipes
        }

        if let data = UserDefaults.standard.data(forKey: Self.categoriesKey),
           let savedCategories = try? JSONDecoder().decode([String].self, from: data),
           !savedCategories.isEmpty {
            categories = savedCategories
        }

        if let data = UserDefaults.standard.data(forKey: Self.hiddenDefaultIngredientsKey),
           let hiddenNames = try? JSONDecoder().decode([String].self, from: data) {
            hiddenDefaultIngredients = hiddenNames
        }

        var hiddenNames: Set<String> = []
        for hiddenName in hiddenDefaultIngredients {
            hiddenNames.insert(hiddenName.lowercased())
        }

        // Auch selbst im Code ergänzte Definitionen werden als solche erkannt.
        // So kann später ihr Name geändert oder eine Definition entfernt werden,
        // ohne dass der alte gespeicherte Name als benutzerdefinierte Zutat bleibt.
        var previouslyCodeDefinedNames = Self.legacyBuiltInIngredientNames
        if let data = UserDefaults.standard.data(forKey: Self.codeDefinedIngredientNamesKey),
           let savedNames = try? JSONDecoder().decode([String].self, from: data) {
            for savedName in savedNames {
                previouslyCodeDefinedNames.insert(savedName.lowercased())
            }
        }

        if let data = UserDefaults.standard.data(forKey: Self.ingredientsKey),
           let savedIngredients = try? JSONDecoder().decode([String].self, from: data) {
            var mergedIngredients = IngredientCatalog.definitions
                .map { $0.name }
                .filter { !hiddenNames.contains($0.lowercased()) }

            let savedCustomIngredients = savedIngredients.filter { savedName in
                let normalized = savedName.lowercased()
                return !previouslyCodeDefinedNames.contains(normalized)
                    && !hiddenNames.contains(normalized)
            }

            for savedName in savedCustomIngredients {
                let alreadyExists = mergedIngredients.contains {
                    $0.localizedCaseInsensitiveCompare(savedName) == .orderedSame
                }
                if !alreadyExists {
                    mergedIngredients.append(savedName)
                }
            }
            ingredientCatalog = mergedIngredients
        } else {
            ingredientCatalog = IngredientCatalog.definitions
                .map { $0.name }
                .filter { !hiddenNames.contains($0.lowercased()) }
        }

        if let encodedNames = try? JSONEncoder().encode(IngredientCatalog.definitions.map { $0.name }) {
            UserDefaults.standard.set(encodedNames, forKey: Self.codeDefinedIngredientNamesKey)
        }

        if let data = UserDefaults.standard.data(forKey: Self.categoryColorsKey),
           let savedColors = try? JSONDecoder().decode([String: Int].self, from: data) {
            categoryColors = savedColors
        }

        if let data = UserDefaults.standard.data(forKey: Self.categoryRecipeIDsKey),
           let savedIDs = try? JSONDecoder().decode([String: [UUID]].self, from: data) {
            categoryRecipeIDs = savedIDs
        }

        if let data = UserDefaults.standard.data(forKey: Self.ingredientModifiersKey),
           let savedModifiers = try? JSONDecoder().decode([String: [String]].self, from: data) {
            ingredientModifiers = savedModifiers
        }

        if let data = UserDefaults.standard.data(forKey: Self.ingredientQuantitiesKey),
           let savedQuantities = try? JSONDecoder().decode([String: [String]].self, from: data) {
            ingredientQuantities = savedQuantities
        }

        if let data = UserDefaults.standard.data(forKey: Self.ingredientUnitsKey),
           let savedUnits = try? JSONDecoder().decode([String: [String]].self, from: data) {
            ingredientUnits = savedUnits
        }

        if let data = UserDefaults.standard.data(forKey: Self.ingredientColorsKey),
           let savedColors = try? JSONDecoder().decode([String: Int].self, from: data) {
            ingredientColors = savedColors
        }
    }

    // MARK: Recipes

    func addRecipe(_ recipe: Recipe) {
        recipes.insert(recipe, at: 0)
        guard categories.contains(recipe.category) else { return }
        var ids = recipeIDs(forCategory: recipe.category)
        ids.insert(recipe.id)
        categoryRecipeIDs[recipe.category] = Array(ids)
    }

    func updateRecipe(_ recipe: Recipe) {
        guard let index = recipes.firstIndex(where: { $0.id == recipe.id }) else { return }
        let oldCategory = recipes[index].category
        recipes[index] = recipe

        if oldCategory != recipe.category {
            if categories.contains(oldCategory) {
                var oldIDs = recipeIDs(forCategory: oldCategory)
                oldIDs.remove(recipe.id)
                categoryRecipeIDs[oldCategory] = Array(oldIDs)
            }
            if categories.contains(recipe.category) {
                var newIDs = recipeIDs(forCategory: recipe.category)
                newIDs.insert(recipe.id)
                categoryRecipeIDs[recipe.category] = Array(newIDs)
            }
        } else if categories.contains(recipe.category), categoryRecipeIDs[recipe.category] != nil {
            var ids = recipeIDs(forCategory: recipe.category)
            ids.insert(recipe.id)
            categoryRecipeIDs[recipe.category] = Array(ids)
        }
    }

    func deleteRecipe(id: UUID) {
        recipes.removeAll { $0.id == id }
        var updatedMemberships = categoryRecipeIDs
        for name in Array(updatedMemberships.keys) {
            updatedMemberships[name]?.removeAll { $0 == id }
        }
        categoryRecipeIDs = updatedMemberships
    }

    // MARK: Categories

    func categoryColorIndex(for name: String) -> Int {
        categoryColors[name] ?? AppStyle.whiteColorIndex
    }

    func recipeIDs(forCategory name: String) -> Set<UUID> {
        if let storedIDs = categoryRecipeIDs[name] {
            return Set(storedIDs)
        }
        return Set(recipes.filter { $0.category == name }.map(\.id))
    }

    func recipes(inCategory name: String) -> [Recipe] {
        let ids = recipeIDs(forCategory: name)
        return recipes.filter { ids.contains($0.id) }
    }

    func categories(forRecipeID id: UUID) -> [String] {
        let matching = categories.filter { recipeIDs(forCategory: $0).contains(id) }
        if !matching.isEmpty { return matching }

        guard let recipe = recipes.first(where: { $0.id == id }) else { return [] }
        // Do not display a legacy primary category after it has been explicitly unassigned.
        if categoryRecipeIDs[recipe.category] != nil { return [] }
        return categories.contains(recipe.category) ? [recipe.category] : []
    }

    func addCategory(_ name: String, colorIndex: Int = 7, recipeIDs: Set<UUID> = []) { // 7 = Weiß / keine Farbe
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty else { return }
        guard !categories.contains(where: {
            $0.localizedCaseInsensitiveCompare(cleanedName) == .orderedSame
        }) else { return }

        categories.append(cleanedName)
        categoryColors[cleanedName] = colorIndex
        categoryRecipeIDs[cleanedName] = Array(recipeIDs)
    }

    func updateCategory(
        oldName: String,
        newName: String,
        colorIndex: Int,
        recipeIDs: Set<UUID>
    ) -> Bool {
        let cleanedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty else { return false }
        let duplicateExists = categories.contains {
            $0 != oldName && $0.localizedCaseInsensitiveCompare(cleanedName) == .orderedSame
        }
        guard !duplicateExists, let categoryIndex = categories.firstIndex(of: oldName) else {
            return false
        }

        categories[categoryIndex] = cleanedName
        categoryColors.removeValue(forKey: oldName)
        categoryColors[cleanedName] = colorIndex
        categoryRecipeIDs.removeValue(forKey: oldName)
        categoryRecipeIDs[cleanedName] = Array(recipeIDs)

        if oldName != cleanedName {
            let fallbackCategory = categories.first(where: { $0 != cleanedName }) ?? "Sonstiges"
            var updatedRecipes = recipes
            for index in updatedRecipes.indices where updatedRecipes[index].category == oldName {
                updatedRecipes[index].category = recipeIDs.contains(updatedRecipes[index].id)
                    ? cleanedName
                    : fallbackCategory
            }
            recipes = updatedRecipes
        }
        return true
    }

    func deleteCategory(_ name: String) {
        categories.removeAll { $0 == name }
        categoryColors.removeValue(forKey: name)
        categoryRecipeIDs.removeValue(forKey: name)

        let fallback = categories.first ?? "Sonstiges"
        var updatedRecipes = recipes
        var movedRecipeIDs: Set<UUID> = []
        for index in updatedRecipes.indices where updatedRecipes[index].category == name {
            updatedRecipes[index].category = fallback
            movedRecipeIDs.insert(updatedRecipes[index].id)
        }
        recipes = updatedRecipes
        if categoryRecipeIDs[fallback] != nil {
            var fallbackIDs = recipeIDs(forCategory: fallback)
            fallbackIDs.formUnion(movedRecipeIDs)
            categoryRecipeIDs[fallback] = Array(fallbackIDs)
        }
    }

    func setRecipeIDs(_ ids: Set<UUID>, forCategory name: String) {
        guard categories.contains(name) else { return }
        categoryRecipeIDs[name] = Array(ids)
    }

    // MARK: Ingredient catalog

    func ingredientColorIndex(for name: String) -> Int {
        ingredientColors[name] ?? AppStyle.whiteColorIndex
    }

    func quantitySuggestions(forIngredient name: String) -> [String] {
        ingredientQuantities[name] ??
            IngredientCatalog.definition(for: name)?.quantitySuggestions ??
            IngredientCatalog.fallbackQuantitySuggestions
    }

    func unitSuggestions(forIngredient name: String) -> [String] {
        ingredientUnits[name] ??
            IngredientCatalog.definition(for: name)?.unitSuggestions ??
            IngredientCatalog.fallbackUnitSuggestions
    }

    func modifiers(forIngredient name: String) -> [String] {
        ingredientModifiers[name] ??
            IngredientCatalog.definition(for: name)?.modifierSuggestions ?? []
    }

    func addIngredient(
        _ name: String,
        quantitySuggestions: [String]? = nil,
        unitSuggestions: [String]? = nil,
        modifiers: [String] = [],
        colorIndex: Int = 7 // Weiß / keine Farbe
    ) {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty else { return }
        guard !ingredientCatalog.contains(where: {
            $0.localizedCaseInsensitiveCompare(cleanedName) == .orderedSame
        }) else { return }
        ingredientCatalog.append(cleanedName)
        // Datenbank-Vorschläge erst hier auflösen, nicht in den Default-Parametern.
        let resolvedQuantities: [String] = quantitySuggestions ?? IngredientCatalog.fallbackQuantitySuggestions
        let resolvedUnits: [String] = unitSuggestions ?? IngredientCatalog.fallbackUnitSuggestions
        ingredientQuantities[cleanedName] = resolvedQuantities
        ingredientUnits[cleanedName] = resolvedUnits
        ingredientModifiers[cleanedName] = modifiers
        ingredientColors[cleanedName] = colorIndex
    }

    func updateIngredient(
        oldName: String,
        newName: String,
        quantitySuggestions: [String],
        unitSuggestions: [String],
        modifiers: [String],
        colorIndex: Int
    ) -> Bool {
        let cleanedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty else { return false }
        let duplicateExists = ingredientCatalog.contains {
            $0 != oldName && $0.localizedCaseInsensitiveCompare(cleanedName) == .orderedSame
        }
        guard !duplicateExists, let ingredientIndex = ingredientCatalog.firstIndex(of: oldName) else {
            return false
        }

        ingredientCatalog[ingredientIndex] = cleanedName

        if oldName != cleanedName,
           IngredientCatalog.definition(for: oldName) != nil,
           !hiddenDefaultIngredients.contains(where: {
               $0.localizedCaseInsensitiveCompare(oldName) == .orderedSame
           }) {
            hiddenDefaultIngredients.append(oldName)
        }

        ingredientModifiers.removeValue(forKey: oldName)
        ingredientModifiers[cleanedName] = modifiers
        ingredientQuantities.removeValue(forKey: oldName)
        ingredientQuantities[cleanedName] = quantitySuggestions
        ingredientUnits.removeValue(forKey: oldName)
        ingredientUnits[cleanedName] = unitSuggestions
        ingredientColors.removeValue(forKey: oldName)
        ingredientColors[cleanedName] = colorIndex

        if oldName != cleanedName {
            var updatedRecipes = recipes
            for recipeIndex in updatedRecipes.indices {
                for ingredientIndex in updatedRecipes[recipeIndex].ingredients.indices {
                    if updatedRecipes[recipeIndex].ingredients[ingredientIndex].name == oldName {
                        updatedRecipes[recipeIndex].ingredients[ingredientIndex].name = cleanedName
                    }
                }
            }
            recipes = updatedRecipes
        }
        return true
    }

    func deleteIngredient(_ name: String) {
        ingredientCatalog.removeAll {
            $0.localizedCaseInsensitiveCompare(name) == .orderedSame
        }
        if IngredientCatalog.definition(for: name) != nil,
           !hiddenDefaultIngredients.contains(where: {
               $0.localizedCaseInsensitiveCompare(name) == .orderedSame
           }) {
            hiddenDefaultIngredients.append(name)
        }
        ingredientModifiers.removeValue(forKey: name)
        ingredientQuantities.removeValue(forKey: name)
        ingredientUnits.removeValue(forKey: name)
        ingredientColors.removeValue(forKey: name)
        // Ingredients already used in recipes are intentionally kept there.
    }

    private func save<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

// MARK: - Shared styling

private enum AppStyle {
    static let orange = Color(red: 1.00, green: 0.70, blue: 0.29)
    static let ink = Color.black.opacity(0.82)
    static let line = Color.black.opacity(0.62)
    static let horizontalPadding: CGFloat = 20

    // Only explicit colors are listed here. White is the default state and
    // is represented by whiteColorIndex instead of an extra selectable swatch.
    static let ingredientColors: [Color] = [
        Color(red: 1.00, green: 0.70, blue: 0.29), // orange
        Color(red: 1.00, green: 0.94, blue: 0.58), // yellow
        Color(red: 1.00, green: 0.62, blue: 0.68), // pink
        Color(red: 0.48, green: 0.85, blue: 0.94), // turquoise
        Color(red: 0.27, green: 0.66, blue: 0.94), // blue
        Color(red: 0.87, green: 0.48, blue: 0.91), // purple
        Color(red: 1.00, green: 0.32, blue: 0.37)  // red
    ]

    // Keep 7 as the no-color value so previously saved recipes remain compatible.
    static let whiteColorIndex = 7

    static func color(for index: Int) -> Color {
        guard ingredientColors.indices.contains(index) else { return .white }
        return ingredientColors[index]
    }

    static func pillText() -> Font {
        .system(size: 28, weight: .regular, design: .monospaced)
    }

    static func heading() -> Font {
        .system(size: 27, weight: .regular, design: .monospaced)
    }
}

struct CircleIconButton: View {
    let symbol: String
    var action: () -> Void

    private var label: String {
        switch symbol {
        case "magnifyingglass": return "Suche öffnen"
        case "plus": return "Hinzufügen"
        case "chevron.left": return "Zurück"
        default: return "Schließen"
        }
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(.black)
                .frame(width: 41, height: 41)
                .background(Circle().fill(.white))
                .overlay(Circle().stroke(AppStyle.line, lineWidth: 0.8))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct OrangeCircleButton: View {
    let symbol: String
    var size: CGFloat = 60
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(.black)
                .frame(width: size, height: size)
                .background(AppStyle.orange, in: Circle())
                .overlay(Circle().stroke(AppStyle.line, lineWidth: 0.8))
        }
        .buttonStyle(.plain)
    }
}

struct SearchField: View {
    @Binding var text: String
    var placeholder: String = "Rezepte suchen"

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.black.opacity(0.65))
            TextField(placeholder, text: $text)
                .font(.system(size: 17, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.black.opacity(0.45))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 15)
        .frame(height: 46)
        .overlay(Capsule().stroke(AppStyle.line, lineWidth: 0.8))
    }
}

struct OutlinePill: View {
    let title: String
    var filled: Bool = false
    var fillColor: Color? = nil

    var body: some View {
        Text(title)
            .font(AppStyle.pillText())
            .foregroundStyle(.black)
            .padding(.horizontal, 19)
            .padding(.vertical, 10)
            .background(fillColor ?? (filled ? AppStyle.orange : .white), in: Capsule())
            .overlay(Capsule().stroke(AppStyle.line, lineWidth: 0.8))
            .fixedSize(horizontal: true, vertical: false)
    }
}

struct SmallOutlinePill: View {
    let title: String
    var fillColor: Color = .white

    var body: some View {
        Text(title)
            .font(.system(size: 19, weight: .regular, design: .monospaced))
            .foregroundStyle(.black)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(fillColor, in: Capsule())
            .overlay(Capsule().stroke(AppStyle.line, lineWidth: 0.8))
            .fixedSize(horizontal: true, vertical: false)
    }
}

/// Lays out pill buttons from left to right and starts a new row only
/// when the next item no longer fits. Each pill keeps its natural width.
struct LeftAlignedFlowLayout: Layout {
    var horizontalSpacing: CGFloat = 10
    var verticalSpacing: CGFloat = 10

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let availableWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var contentWidth: CGFloat = 0

        for subview in subviews {
            let itemSize = subview.sizeThatFits(.unspecified)
            let requiredWidth = itemSize.width + (currentX > 0 ? horizontalSpacing : 0)

            if currentX > 0 && currentX + requiredWidth > availableWidth {
                contentWidth = max(contentWidth, currentX)
                currentX = 0
                currentY += rowHeight + verticalSpacing
                rowHeight = 0
            }

            if currentX > 0 {
                currentX += horizontalSpacing
            }
            currentX += itemSize.width
            rowHeight = max(rowHeight, itemSize.height)
            contentWidth = max(contentWidth, currentX)
        }

        return CGSize(
            width: proposal.width ?? contentWidth,
            height: currentY + rowHeight
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let itemSize = subview.sizeThatFits(.unspecified)
            let nextX = currentX + (currentX > bounds.minX ? horizontalSpacing : 0)

            if currentX > bounds.minX && nextX + itemSize.width > bounds.maxX {
                currentX = bounds.minX
                currentY += rowHeight + verticalSpacing
                rowHeight = 0
            }

            if currentX > bounds.minX {
                currentX += horizontalSpacing
            }

            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(width: itemSize.width, height: itemSize.height)
            )

            currentX += itemSize.width
            rowHeight = max(rowHeight, itemSize.height)
        }
    }
}

/// Colored ingredient chip used in the recipe editor and recipe detail.
struct IngredientPill: View {
    let title: String
    let fillColor: Color
    var fontSize: CGFloat = 15

    var body: some View {
        Text(title)
            .font(.system(size: fontSize, weight: .regular, design: .monospaced))
            .foregroundStyle(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(fillColor, in: Capsule())
            .overlay(Capsule().stroke(AppStyle.line, lineWidth: 0.7))
            .fixedSize(horizontal: true, vertical: false)
    }
}

struct IngredientColorPicker: View {
    @Binding var selectedIndex: Int

    var body: some View {
        // Equal-width slots keep all seven swatches inside the available content
        // width, including on smaller devices and inside sheet presentations.
        HStack(spacing: 0) {
            ForEach(AppStyle.ingredientColors.indices, id: \.self) { index in
                Button {
                    selectedIndex = index
                } label: {
                    Circle()
                        .fill(AppStyle.color(for: index))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle().stroke(
                                selectedIndex == index ? Color.black.opacity(0.85) : Color.black.opacity(0.25),
                                lineWidth: selectedIndex == index ? 1.4 : 0.6
                            )
                        )
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Farbe \(index + 1)")
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 40)
    }
}

// MARK: - Root / start screen

struct ContentView: View {
    var body: some View {
        NavigationStack {
            HomeView()
        }
        .tint(.black)
    }
}

struct HomeView: View {
    @EnvironmentObject private var store: RecipeStore
    @State private var isSearching = false
    @State private var searchText = ""

    private var searchResults: [Recipe] {
        guard !searchText.isEmpty else { return [] }
        return store.recipes.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            store.categories(forRecipeID: $0.id).contains(where: { $0.localizedCaseInsensitiveContains(searchText) }) ||
            $0.ingredients.contains(where: {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.amount.localizedCaseInsensitiveContains(searchText) ||
                $0.modifier.localizedCaseInsensitiveContains(searchText)
            }) ||
            $0.instructions.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Meine Rezepte")
                    .font(AppStyle.heading())
                    .foregroundStyle(.black)
                Spacer()
                CircleIconButton(symbol: isSearching ? "xmark" : "magnifyingglass") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSearching.toggle()
                        searchText = ""
                    }
                }
            }
            .padding(.top, 22)

            if isSearching {
                SearchField(text: $searchText)
                    .padding(.top, 18)
                searchResultsView
                    .padding(.top, 18)
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 30)
                VStack(spacing: 20) {
                    NavigationLink {
                        RecipeFormView()
                    } label: {
                        OutlinePill(title: "Neues Rezept", filled: true)
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        RecipeBookView()
                    } label: {
                        OutlinePill(title: "Zum Backbuch")
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 30)
            }
        }
        .padding(.horizontal, AppStyle.horizontalPadding)
        .background(.white)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private var searchResultsView: some View {
        if searchText.isEmpty {
            Text("Suche nach Rezeptnamen, Zutaten oder Kategorien.")
                .font(.system(size: 15, design: .monospaced))
                .foregroundStyle(.black.opacity(0.55))
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if searchResults.isEmpty {
            Text("Keine Rezepte gefunden.")
                .font(.system(size: 16, design: .monospaced))
                .foregroundStyle(.black.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(searchResults) { recipe in
                        NavigationLink {
                            RecipeDetailView(recipe: recipe)
                        } label: {
                            RecipeRow(recipe: recipe)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - Screen 01: recipe book / categories

struct RecipeBookView: View {
    @EnvironmentObject private var store: RecipeStore
    @Environment(\.dismiss) private var dismiss
    @State private var isSearching = false
    @State private var searchText = ""
    @State private var showingCategoryEditor = false
    @State private var editingCategory: String?

    private var searchResults: [Recipe] {
        guard !searchText.isEmpty else { return [] }
        return store.recipes.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            store.categories(forRecipeID: $0.id).contains(where: { $0.localizedCaseInsensitiveContains(searchText) }) ||
            $0.ingredients.contains(where: {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.amount.localizedCaseInsensitiveContains(searchText) ||
                $0.modifier.localizedCaseInsensitiveContains(searchText)
            }) ||
            $0.instructions.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                CircleIconButton(symbol: "chevron.left") { dismiss() }
                    .accessibilityLabel("Zur Startseite")
                Text("Rezepte")
                    .font(AppStyle.heading())
                    .foregroundStyle(.black)
                Spacer()
                CircleIconButton(symbol: isSearching ? "xmark" : "magnifyingglass") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSearching.toggle()
                        searchText = ""
                    }
                }
            }
            .padding(.top, 22)

            if isSearching {
                SearchField(text: $searchText)
                    .padding(.top, 18)
                searchResultsView
                    .padding(.top, 18)
                Spacer(minLength: 0)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(store.categories, id: \.self) { category in
                            NavigationLink {
                                CategoryRecipesView(category: category)
                            } label: {
                                OutlinePill(
                                    title: category,
                                    fillColor: AppStyle.color(for: store.categoryColorIndex(for: category))
                                )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Kategorie bearbeiten", systemImage: "pencil") {
                                    editingCategory = category
                                    showingCategoryEditor = true
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                }
            }
        }
        .padding(.horizontal, AppStyle.horizontalPadding)
        .background(.white)
        .safeAreaInset(edge: .bottom, alignment: .trailing, spacing: 0) {
            if !isSearching {
                OrangeCircleButton(symbol: "plus", size: 60) {
                    editingCategory = nil
                    showingCategoryEditor = true
                }
                .padding(.trailing, 20)
                .padding(.bottom, 18)
            }
        }
        .sheet(isPresented: $showingCategoryEditor) {
            CategoryEditorView(existingCategory: editingCategory)
                .environmentObject(store)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(.white)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private var searchResultsView: some View {
        if searchText.isEmpty {
            Text("Suche nach Rezeptnamen, Zutaten oder Kategorien.")
                .font(.system(size: 15, design: .monospaced))
                .foregroundStyle(.black.opacity(0.55))
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if searchResults.isEmpty {
            Text("Keine Rezepte gefunden.")
                .font(.system(size: 16, design: .monospaced))
                .foregroundStyle(.black.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(searchResults) { recipe in
                        NavigationLink {
                            RecipeDetailView(recipe: recipe)
                        } label: {
                            RecipeRow(recipe: recipe)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - Category create / edit

struct CategoryEditorView: View {
    @EnvironmentObject private var store: RecipeStore
    @Environment(\.dismiss) private var dismiss

    let existingCategory: String?
    @State private var title: String
    @State private var selectedColorIndex: Int = AppStyle.whiteColorIndex
    @State private var selectedRecipeIDs: Set<UUID> = []
    @State private var showingRecipeSelection = false
    @State private var showingDeleteConfirmation = false
    @State private var showingDuplicateAlert = false

    init(existingCategory: String? = nil) {
        self.existingCategory = existingCategory
        _title = State(initialValue: existingCategory ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(existingCategory == nil ? "Neue Kategorie" : "Kategorie bearbeiten")
                    .font(AppStyle.heading())
                Spacer()
                CircleIconButton(symbol: "xmark") { dismiss() }
            }
            .padding(.top, 22)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    TextField("Titel", text: $title)
                        .font(.system(size: 19, design: .monospaced))
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 40)
                        .overlay(Capsule().stroke(AppStyle.line, lineWidth: 0.8))
                        .padding(.top, 20)

                    IngredientColorPicker(selectedIndex: $selectedColorIndex)
                        .padding(.top, 320)

                    Button {
                        showingRecipeSelection = true
                    } label: {
                        HStack(spacing: 8) {
                            Text("Rezepte hinzufügen")
                            if !selectedRecipeIDs.isEmpty {
                                Text("(\(selectedRecipeIDs.count))")
                                    .foregroundStyle(.black.opacity(0.55))
                            }
                        }
                        .font(.system(size: 18, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.white, in: Capsule())
                        .overlay(Capsule().stroke(AppStyle.line, lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 18)
                    .padding(.bottom, 20)

                    if existingCategory != nil {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Kategorie löschen", systemImage: "trash")
                                .font(.system(size: 15, design: .monospaced))
                                .foregroundStyle(.red.opacity(0.85))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .overlay(Capsule().stroke(.red.opacity(0.45), lineWidth: 0.8))
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 16)
                    }
                }
            }

            OrangeCircleButton(symbol: "checkmark", size: 60) {
                saveCategory()
            }
            .padding(.top, 10)
            .padding(.bottom, 14)
        }
        .padding(.horizontal, AppStyle.horizontalPadding)
        .background(.white)
        .onAppear {
            if let existingCategory {
                selectedColorIndex = store.categoryColorIndex(for: existingCategory)
                selectedRecipeIDs = store.recipeIDs(forCategory: existingCategory)
            }
        }
        .sheet(isPresented: $showingRecipeSelection) {
            RecipeSelectionSheet(
                selectedRecipeIDs: selectedRecipeIDs,
                categoryColorIndex: selectedColorIndex
            ) { ids in
                selectedRecipeIDs = ids
            }
            .environmentObject(store)
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            .presentationBackground(.white)
        }
        .alert("Kategorie existiert bereits", isPresented: $showingDuplicateAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Bitte wähle einen anderen Namen.")
        }
        .confirmationDialog("Kategorie löschen?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Kategorie endgültig löschen", role: .destructive) {
                if let existingCategory {
                    store.deleteCategory(existingCategory)
                }
                dismiss()
            }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Die Rezepte selbst bleiben erhalten.")
        }
    }

    private func saveCategory() {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty else { return }

        if let existingCategory {
            let saved = store.updateCategory(
                oldName: existingCategory,
                newName: cleanedTitle,
                colorIndex: selectedColorIndex,
                recipeIDs: selectedRecipeIDs
            )
            if !saved {
                showingDuplicateAlert = true
                return
            }
        } else {
            let duplicate = store.categories.contains {
                $0.localizedCaseInsensitiveCompare(cleanedTitle) == .orderedSame
            }
            guard !duplicate else {
                showingDuplicateAlert = true
                return
            }
            store.addCategory(cleanedTitle, colorIndex: selectedColorIndex, recipeIDs: selectedRecipeIDs)
        }
        dismiss()
    }
}

// MARK: - Select recipes for a category

struct RecipeSelectionSheet: View {
    @EnvironmentObject private var store: RecipeStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedRecipeIDs: Set<UUID>
    let categoryColorIndex: Int
    let onSave: (Set<UUID>) -> Void

    init(
        selectedRecipeIDs: Set<UUID>,
        categoryColorIndex: Int,
        onSave: @escaping (Set<UUID>) -> Void
    ) {
        _selectedRecipeIDs = State(initialValue: selectedRecipeIDs)
        self.categoryColorIndex = categoryColorIndex
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Alle Rezepte")
                    .font(AppStyle.heading())
                Spacer()
                CircleIconButton(symbol: "xmark") { dismiss() }
            }
            .padding(.top, 22)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    ForEach(store.recipes) { recipe in
                        Button {
                            toggle(recipe.id)
                        } label: {
                            ZStack(alignment: .bottomTrailing) {
                                RecipeRow(recipe: recipe)
                                selectionDot(isSelected: selectedRecipeIDs.contains(recipe.id))
                                    .padding(9)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 24)
            }

            OrangeCircleButton(symbol: "checkmark", size: 60) {
                onSave(selectedRecipeIDs)
                dismiss()
            }
            .padding(.top, 8)
            .padding(.bottom, 14)
        }
        .padding(.horizontal, AppStyle.horizontalPadding)
        .background(.white)
    }

    private func toggle(_ id: UUID) {
        if selectedRecipeIDs.contains(id) {
            selectedRecipeIDs.remove(id)
        } else {
            selectedRecipeIDs.insert(id)
        }
    }

    private func selectionDot(isSelected: Bool) -> some View {
        Circle()
            .fill(isSelected
                  ? (categoryColorIndex == AppStyle.whiteColorIndex
                     ? Color.black.opacity(0.20)
                     : AppStyle.color(for: categoryColorIndex))
                  : .white)
            .frame(width: 21, height: 21)
            .overlay(Circle().stroke(AppStyle.line, lineWidth: 0.8))
    }
}

// MARK: - Ingredient catalog create / edit

struct IngredientDefinitionEditorView: View {
    @EnvironmentObject private var store: RecipeStore
    @Environment(\.dismiss) private var dismiss

    let existingName: String?
    @State private var name: String
    @State private var quantitySuggestionsText = ""
    @State private var unitSuggestionsText = ""
    @State private var modifiersText = ""
    @State private var selectedColorIndex = AppStyle.whiteColorIndex
    @State private var showingDuplicateAlert = false
    @State private var showingDeleteConfirmation = false

    init(existingName: String? = nil) {
        self.existingName = existingName
        _name = State(initialValue: existingName ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(existingName == nil ? "Neue Zutat" : "Zutat bearbeiten")
                    .font(AppStyle.heading())
                Spacer()
                CircleIconButton(symbol: "xmark") { dismiss() }
            }
            .padding(.top, 22)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    TextField("Name der Zutat", text: $name)
                        .font(.system(size: 19, design: .monospaced))
                        .padding(.horizontal, 14)
                        .frame(height: 42)
                        .overlay(Capsule().stroke(AppStyle.line, lineWidth: 0.8))
                        .padding(.top, 20)

                    Text("Mengenvorschläge")
                        .font(.system(size: 18, design: .monospaced))
                    TextEditor(text: $quantitySuggestionsText)
                        .font(.system(size: 15, design: .monospaced))
                        .frame(minHeight: 72)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppStyle.line, lineWidth: 0.8))
                    Text("Werte mit Komma oder Zeilenumbruch trennen, z. B. 50, 100, 250, 500.")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.black.opacity(0.55))
                        .padding(.top, -14)

                    Text("Einheiten")
                        .font(.system(size: 18, design: .monospaced))
                    TextEditor(text: $unitSuggestionsText)
                        .font(.system(size: 15, design: .monospaced))
                        .frame(minHeight: 58)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppStyle.line, lineWidth: 0.8))
                    Text("Einheiten mit Komma oder Zeilenumbruch trennen, z. B. g, kg, EL.")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.black.opacity(0.55))
                        .padding(.top, -14)

                    Text("Zusätze / Varianten")
                        .font(.system(size: 18, design: .monospaced))
                    TextEditor(text: $modifiersText)
                        .font(.system(size: 16, design: .monospaced))
                        .frame(minHeight: 110)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppStyle.line, lineWidth: 0.8))
                    Text("Ein Zusatz pro Zeile, z. B. gemahlen, gehackt oder gehobelt.")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.black.opacity(0.55))
                        .padding(.top, -14)

                    Text("Standardfarbe")
                        .font(.system(size: 18, design: .monospaced))
                    IngredientColorPicker(selectedIndex: $selectedColorIndex)

                    if existingName != nil {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Zutat aus der Liste entfernen", systemImage: "trash")
                                .font(.system(size: 15, design: .monospaced))
                                .foregroundStyle(.red.opacity(0.85))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .overlay(Capsule().stroke(.red.opacity(0.45), lineWidth: 0.8))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 10)
                    }
                }
            }

            OrangeCircleButton(symbol: "checkmark", size: 60) {
                saveIngredient()
            }
            .padding(.top, 10)
            .padding(.bottom, 14)
        }
        .padding(.horizontal, AppStyle.horizontalPadding)
        .background(.white)
        .onAppear {
            if let existingName {
                quantitySuggestionsText = store.quantitySuggestions(forIngredient: existingName).joined(separator: ", ")
                unitSuggestionsText = store.unitSuggestions(forIngredient: existingName).joined(separator: ", ")
                modifiersText = store.modifiers(forIngredient: existingName).joined(separator: "\n")
                selectedColorIndex = store.ingredientColorIndex(for: existingName)
            } else {
                quantitySuggestionsText = IngredientCatalog.fallbackQuantitySuggestions.joined(separator: ", ")
                unitSuggestionsText = IngredientCatalog.fallbackUnitSuggestions.joined(separator: ", ")
            }
        }
        .alert("Zutat existiert bereits", isPresented: $showingDuplicateAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Bitte wähle einen anderen Namen.")
        }
        .confirmationDialog("Zutat entfernen?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Zutat entfernen", role: .destructive) {
                if let existingName { store.deleteIngredient(existingName) }
                dismiss()
            }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Bereits gespeicherte Rezepte behalten diese Zutat.")
        }
    }

    private func saveIngredient() {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty else { return }
        let quantities = parseSuggestionList(quantitySuggestionsText)
        let units = parseSuggestionList(unitSuggestionsText)
        let modifiers = parseSuggestionList(modifiersText)

        if let existingName {
            let saved = store.updateIngredient(
                oldName: existingName,
                newName: cleanedName,
                quantitySuggestions: quantities,
                unitSuggestions: units,
                modifiers: modifiers,
                colorIndex: selectedColorIndex
            )
            guard saved else {
                showingDuplicateAlert = true
                return
            }
        } else {
            let duplicate = store.ingredientCatalog.contains {
                $0.localizedCaseInsensitiveCompare(cleanedName) == .orderedSame
            }
            guard !duplicate else {
                showingDuplicateAlert = true
                return
            }
            store.addIngredient(
                cleanedName,
                quantitySuggestions: quantities,
                unitSuggestions: units,
                modifiers: modifiers,
                colorIndex: selectedColorIndex
            )
        }
        dismiss()
    }

    private func parseSuggestionList(_ text: String) -> [String] {
        text.components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - Category results

struct CategoryRecipesView: View {
    let category: String
    @EnvironmentObject private var store: RecipeStore
    @Environment(\.dismiss) private var dismiss

    private var recipes: [Recipe] {
        store.recipes(inCategory: category)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                CircleIconButton(symbol: "chevron.left") { dismiss() }
                Text(category)
                    .font(AppStyle.heading())
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer()
            }
            .padding(.top, 22)

            if recipes.isEmpty {
                Spacer()
                Text("In dieser Kategorie sind noch keine Rezepte.")
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundStyle(.black.opacity(0.55))
                    .multilineTextAlignment(.center)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(recipes) { recipe in
                            NavigationLink {
                                RecipeDetailView(recipe: recipe)
                            } label: {
                                RecipeRow(recipe: recipe)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 22)
                }
            }
        }
        .padding(.horizontal, AppStyle.horizontalPadding)
        .background(.white)
        .safeAreaInset(edge: .bottom, alignment: .trailing, spacing: 0) {
            OrangeCircleButton(symbol: "plus", size: 60) {
                // The form receives the current category as its initial selection.
                showingNewRecipe = true
            }
            .padding(.trailing, 20)
            .padding(.bottom, 18)
        }
        .navigationDestination(isPresented: $showingNewRecipe) {
            RecipeFormView(initialCategory: category)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    @State private var showingNewRecipe = false
}

// MARK: - Screen 02: create / edit recipe

struct RecipeFormView: View {
    @EnvironmentObject private var store: RecipeStore
    @Environment(\.dismiss) private var dismiss

    private let existingRecipe: Recipe?

    @State private var title: String
    @State private var selectedIngredients: [RecipeIngredient]
    @State private var instructionFields: [String]
    @State private var selectedCategory: String
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var showingTitleAlert = false
    @State private var showingDeleteConfirmation = false
    @State private var showingIngredientPicker = false
    @FocusState private var titleFieldFocused: Bool

    init(existingRecipe: Recipe? = nil, initialCategory: String? = nil) {
        self.existingRecipe = existingRecipe
        _title = State(initialValue: existingRecipe?.title ?? "")
        _selectedIngredients = State(initialValue: existingRecipe?.ingredients ?? [])
        _instructionFields = State(initialValue: existingRecipe?.instructions ?? [])
        _selectedCategory = State(initialValue: existingRecipe?.category ?? initialCategory ?? "")
        _imageData = State(initialValue: existingRecipe?.imageData)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(existingRecipe == nil ? "Neues Rezept" : "Rezept bearbeiten")
                    .font(AppStyle.heading())
                    .foregroundStyle(.black)
                Spacer()
                CircleIconButton(symbol: "xmark") { dismiss() }
            }
            .padding(.top, 22)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    TextField("Titel", text: $title)
                        .font(.system(size: 20, weight: .regular, design: .monospaced))
                        .focused($titleFieldFocused)
                        .submitLabel(.next)
                        .padding(.horizontal, 15)
                        .frame(height: 40)
                        .background(.white, in: Capsule())
                        .overlay(Capsule().stroke(AppStyle.line, lineWidth: 0.8))
                        .padding(.top, 20)

                    photoPicker
                    ingredientsSection
                    instructionsSection
                    categoryPicker
                        .padding(.bottom, 10)

                    if existingRecipe != nil {
                        deleteRecipeButton
                            .padding(.top, 8)
                            .padding(.bottom, 28)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            OrangeCircleButton(symbol: "checkmark", size: 60) {
                saveRecipe()
            }
            .padding(.top, 12)
            .padding(.bottom, 14)
        }
        .padding(.horizontal, AppStyle.horizontalPadding)
        .background(.white)
        .onAppear {
            if existingRecipe == nil {
                titleFieldFocused = true
            }
        }
        .onChange(of: selectedPhoto) { _, newPhoto in
            guard let newPhoto else { return }
            Task {
                if let data = try? await newPhoto.loadTransferable(type: Data.self) {
                    imageData = Self.optimizedImageData(from: data) ?? data
                }
            }
        }
        .sheet(isPresented: $showingIngredientPicker) {
            IngredientPickerView(selectedIngredients: $selectedIngredients)
                .environmentObject(store)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(.white)
        }
        .alert("Titel fehlt", isPresented: $showingTitleAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Bitte gib deinem Rezept zuerst einen Titel.")
        }
        .confirmationDialog("Rezept löschen?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Rezept endgültig löschen", role: .destructive) {
                deleteRecipe()
            }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Dieses Rezept wird dauerhaft aus deinem Backbuch entfernt.")
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var deleteRecipeButton: some View {
        Button(role: .destructive) {
            showingDeleteConfirmation = true
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "trash")
                Text("Rezept löschen")
            }
            .font(.system(size: 16, design: .monospaced))
            .foregroundStyle(Color.red.opacity(0.85))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(.white, in: Capsule())
            .overlay(Capsule().stroke(Color.red.opacity(0.55), lineWidth: 0.8))
        }
        .buttonStyle(.plain)
    }

    private func deleteRecipe() {
        guard let existingRecipe else { return }
        store.deleteRecipe(id: existingRecipe.id)
        dismiss()
    }

    private var photoPicker: some View {
        PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
            ZStack {
                if let imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .clipped()
                } else {
                    AppStyle.orange
                    Text("Bild einfügen")
                        .font(.system(size: 15, weight: .regular, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 7)
                        .background(.white, in: Capsule())
                        .overlay(Capsule().stroke(AppStyle.line, lineWidth: 0.7))
                }
            }
            .frame(height: 220)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                SmallOutlinePill(title: "Zutaten")
                Button {
                    titleFieldFocused = false
                    showingIngredientPicker = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.black)
                        .frame(width: 40, height: 40)
                        .background(.white, in: Circle())
                        .overlay(Circle().stroke(AppStyle.line, lineWidth: 0.8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Zutaten auswählen")
            }

            if !selectedIngredients.isEmpty {
                LeftAlignedFlowLayout(horizontalSpacing: 10, verticalSpacing: 9) {
                    ForEach(selectedIngredients) { ingredient in
                        IngredientPill(
                            title: ingredient.displayText,
                            fillColor: AppStyle.color(for: ingredient.colorIndex).opacity(0.72)
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                SmallOutlinePill(title: "Zubereitung")
                Button {
                    instructionFields.append("")
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.black)
                        .frame(width: 40, height: 40)
                        .background(.white, in: Circle())
                        .overlay(Circle().stroke(AppStyle.line, lineWidth: 0.8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Zubereitungsschritt hinzufügen")
            }

            ForEach(instructionFields.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: 8) {
                    TextField("Schritt beschreiben", text: $instructionFields[index], axis: .vertical)
                        .lineLimit(2...5)
                        .font(.system(size: 15, design: .monospaced))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white, in: RoundedRectangle(cornerRadius: 13))
                        .overlay(RoundedRectangle(cornerRadius: 13).stroke(AppStyle.line, lineWidth: 0.7))

                    Button {
                        instructionFields.remove(at: index)
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 20))
                            .foregroundStyle(.black.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 11)
                }
            }
        }
    }

    private var categoryPicker: some View {
        Menu {
            ForEach(store.categories, id: \.self) { category in
                Button(category) { selectedCategory = category }
            }
        } label: {
            HStack(spacing: 8) {
                Text(selectedCategory.isEmpty ? "Kategorie" : selectedCategory)
                    .font(.system(size: 19, weight: .regular, design: .monospaced))
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .regular))
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.white, in: Capsule())
            .overlay(Capsule().stroke(AppStyle.line, lineWidth: 0.8))
        }
    }

    private static func optimizedImageData(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longestSide = max(image.size.width, image.size.height)
        guard longestSide > 0 else { return nil }

        let scale = min(1, 1400 / longestSide)
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.jpegData(withCompressionQuality: 0.78) { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    private func saveRecipe() {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty else {
            showingTitleAlert = true
            return
        }

        let recipe = Recipe(
            id: existingRecipe?.id ?? UUID(),
            title: cleanedTitle,
            imageData: imageData,
            ingredients: selectedIngredients,
            instructions: instructionFields.map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }.filter { !$0.isEmpty },
            category: selectedCategory.isEmpty ? "Sonstiges" : selectedCategory
        )

        if existingRecipe == nil {
            store.addRecipe(recipe)
        } else {
            store.updateRecipe(recipe)
        }
        dismiss()
    }
}

// MARK: - Ingredient picker overlay (Zutaten.png)

struct IngredientPickerView: View {
    @EnvironmentObject private var store: RecipeStore
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedIngredients: [RecipeIngredient]

    @State private var isSearching = false
    @State private var searchText = ""
    @State private var showingIngredientEditor = false
    @State private var editingIngredient: String?
    @State private var path: [String] = []

    private var filteredIngredients: [String] {
        guard !searchText.isEmpty else { return store.ingredientCatalog }
        return store.ingredientCatalog.filter {
            $0.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                HStack {
                    Text("Zutaten")
                        .font(AppStyle.heading())
                        .foregroundStyle(.black)
                    Spacer()

                    CircleIconButton(symbol: isSearching ? "xmark" : "magnifyingglass") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isSearching.toggle()
                            searchText = ""
                        }
                    }

                    CircleIconButton(symbol: "plus") {
                        editingIngredient = nil
                        showingIngredientEditor = true
                    }

                    CircleIconButton(symbol: "xmark") { dismiss() }
                }
                .padding(.top, 22)

                if isSearching {
                    SearchField(text: $searchText, placeholder: "Zutaten suchen")
                        .padding(.top, 16)
                }

                ScrollView(showsIndicators: false) {
                    LeftAlignedFlowLayout(horizontalSpacing: 10, verticalSpacing: 18) {
                        ForEach(filteredIngredients, id: \.self) { name in
                            NavigationLink(value: name) {
                                SmallOutlinePill(
                                    title: name,
                                    fillColor: ingredientChipColor(for: name)
                                )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Zutat bearbeiten", systemImage: "pencil") {
                                    editingIngredient = name
                                    showingIngredientEditor = true
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 20)
                    .padding(.bottom, 30)
                }
            }
            .padding(.horizontal, AppStyle.horizontalPadding)
            .background(.white)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                HStack {
                    Spacer()
                    OrangeCircleButton(symbol: "checkmark", size: 60) { dismiss() }
                    Spacer()
                }
                .padding(.top, 10)
                .padding(.bottom, 14)
                .background(.white)
            }
            .navigationDestination(for: String.self) { name in
                IngredientAmountView(
                    name: name,
                    existingIngredient: selectedIngredients.first(where: {
                        $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
                    })
                ) { ingredient in
                    if let index = selectedIngredients.firstIndex(where: {
                        $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
                    }) {
                        selectedIngredients[index] = ingredient
                    } else {
                        selectedIngredients.append(ingredient)
                    }
                }
            }
            .sheet(isPresented: $showingIngredientEditor) {
                IngredientDefinitionEditorView(existingName: editingIngredient)
                    .environmentObject(store)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
                    .presentationBackground(.white)
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(.black)
    }

    private func isSelected(_ name: String) -> Bool {
        selectedIngredients.contains {
            $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
        }
    }

    private func ingredientChipColor(for name: String) -> Color {
        guard isSelected(name) else { return .white }
        let index = selectedIngredients.first(where: {
            $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
        })?.colorIndex ?? store.ingredientColorIndex(for: name)
        return index == AppStyle.whiteColorIndex
            ? Color.black.opacity(0.15)
            : AppStyle.color(for: index).opacity(0.72)
    }
}

// MARK: - Ingredient amount, unit and optional modifier

struct IngredientAmountView: View {
    let name: String
    let existingIngredient: RecipeIngredient?
    let onSave: (RecipeIngredient) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: RecipeStore
    @State private var quantity: String
    @State private var unit: String
    @State private var modifier: String
    @State private var selectedColorIndex: Int
    @State private var showingManualEntry = false

    private var quantitySuggestions: [String] {
        store.quantitySuggestions(forIngredient: name)
    }

    private var unitSuggestions: [String] {
        store.unitSuggestions(forIngredient: name)
    }

    init(
        name: String,
        existingIngredient: RecipeIngredient? = nil,
        onSave: @escaping (RecipeIngredient) -> Void
    ) {
        self.name = name
        self.existingIngredient = existingIngredient
        self.onSave = onSave
        _quantity = State(initialValue: existingIngredient?.quantity ?? "")
        _unit = State(initialValue: existingIngredient?.unit ?? "")
        _modifier = State(initialValue: existingIngredient?.modifier ?? "")
        _selectedColorIndex = State(initialValue: existingIngredient?.colorIndex ?? AppStyle.whiteColorIndex)
    }

    private var modifierSuggestions: [String] {
        store.modifiers(forIngredient: name)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    ingredientNamePill
                    quantitySection
                    unitSection
                    modifierSection
                    IngredientColorPicker(selectedIndex: $selectedColorIndex)
                        .padding(.top, 4)
                    manualEntryButton
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            saveButton
        }
        .padding(.horizontal, AppStyle.horizontalPadding)
        .background(.white)
        .onAppear {
            if existingIngredient == nil {
                selectedColorIndex = store.ingredientColorIndex(for: name)
            }
        }
        .sheet(isPresented: $showingManualEntry) {
            ManualQuantitySheet(
                initialQuantity: quantity,
                initialUnit: unit,
                initialColorIndex: selectedColorIndex
            ) { newQuantity, newUnit, newColor in
                quantity = newQuantity
                unit = newUnit
                selectedColorIndex = newColor
            }
            .presentationDetents([.height(500)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(24)
            .presentationBackground(.white)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack {
            Text("Zutaten")
                .font(AppStyle.heading())
                .foregroundStyle(.black)
            Spacer()
            CircleIconButton(symbol: "xmark") { dismiss() }
        }
        .padding(.top, 22)
    }

    private var ingredientNamePill: some View {
        SmallOutlinePill(
            title: name,
            fillColor: AppStyle.color(for: selectedColorIndex).opacity(0.55)
        )
        .padding(.top, 20)
    }

    private var quantitySection: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("Menge")
                .font(.system(size: 19, design: .monospaced))
            LeftAlignedFlowLayout(horizontalSpacing: 10, verticalSpacing: 12) {
                ForEach(quantitySuggestions, id: \.self) { value in
                    quantityButton(value)
                }
            }
        }
    }

    private func quantityButton(_ value: String) -> some View {
        let isSelected = quantity == value
        // Ausgewählte Vorschläge werden neutral hellgrau markiert.
        // Die gewählte Zutatenfarbe betrifft nur den gespeicherten Zutaten-Chip.
        let buttonColor = isSelected ? Color.black.opacity(0.14) : Color.white
        return Button {
            quantity = value
        } label: {
            SmallOutlinePill(title: value, fillColor: buttonColor)
        }
        .buttonStyle(.plain)
    }

    private var unitSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("Einheit")
                .font(.system(size: 19, design: .monospaced))
            LeftAlignedFlowLayout(horizontalSpacing: 10, verticalSpacing: 12) {
                ForEach(unitSuggestions, id: \.self) { value in
                    unitButton(value)
                }
            }
        }
    }

    private func unitButton(_ value: String) -> some View {
        let isSelected = unit == value
        // Ausgewählte Vorschläge werden neutral hellgrau markiert.
        // Die gewählte Zutatenfarbe betrifft nur den gespeicherten Zutaten-Chip.
        let buttonColor = isSelected ? Color.black.opacity(0.14) : Color.white
        return Button {
            unit = value
        } label: {
            SmallOutlinePill(title: value, fillColor: buttonColor)
        }
        .buttonStyle(.plain)
    }

    private var modifierSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("Zusatz (optional)")
                .font(.system(size: 19, design: .monospaced))

            if !modifierSuggestions.isEmpty {
                LeftAlignedFlowLayout(horizontalSpacing: 10, verticalSpacing: 12) {
                    ForEach(modifierSuggestions, id: \.self) { value in
                        modifierButton(value)
                    }
                }
            }

            TextField("Eigener Zusatz, z. B. fein gehackt", text: $modifier)
                .font(.system(size: 15, design: .monospaced))
                .padding(.horizontal, 14)
                .frame(height: 42)
                .background(.white, in: Capsule())
                .overlay(Capsule().stroke(AppStyle.line, lineWidth: 0.8))
        }
    }

    private func modifierButton(_ value: String) -> some View {
        let isSelected = modifier == value
        // Ausgewählte Vorschläge werden neutral hellgrau markiert.
        // Die gewählte Zutatenfarbe betrifft nur den gespeicherten Zutaten-Chip.
        let buttonColor = isSelected ? Color.black.opacity(0.14) : Color.white
        return Button {
            modifier = isSelected ? "" : value
        } label: {
            SmallOutlinePill(title: value, fillColor: buttonColor)
        }
        .buttonStyle(.plain)
    }

    private var manualEntryButton: some View {
        Button {
            showingManualEntry = true
        } label: {
            SmallOutlinePill(title: "Eingabe")
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
        .padding(.bottom, 20)
    }

    private var saveButton: some View {
        OrangeCircleButton(symbol: "checkmark", size: 60) {
            let ingredient = RecipeIngredient(
                id: existingIngredient?.id ?? UUID(),
                name: name,
                quantity: quantity.trimmingCharacters(in: .whitespacesAndNewlines),
                unit: unit,
                modifier: modifier.trimmingCharacters(in: .whitespacesAndNewlines),
                colorIndex: selectedColorIndex
            )
            onSave(ingredient)
            dismiss()
        }
        .padding(.top, 10)
        .padding(.bottom, 14)
    }
}

// MARK: - Manual amount/unit overlay (Zutaten_Eingabe.png)

struct ManualQuantitySheet: View {
    let onConfirm: (String, String, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var quantity: String
    @State private var selectedUnit: String
    @State private var selectedColorIndex: Int
    @FocusState private var quantityFocused: Bool

    private let units = ["g", "kg", "ml", "l", "EL", "TL", "Msp", "Stück", "Pck", "Prise"]

    init(
        initialQuantity: String,
        initialUnit: String,
        initialColorIndex: Int,
        onConfirm: @escaping (String, String, Int) -> Void
    ) {
        self.onConfirm = onConfirm
        _quantity = State(initialValue: initialQuantity)
        _selectedUnit = State(initialValue: initialUnit)
        _selectedColorIndex = State(initialValue: initialColorIndex)
    }

    var body: some View {
        VStack(spacing: 20) {
            TextField("Menge", text: $quantity)
                .font(.system(size: 21, design: .monospaced))
                .multilineTextAlignment(.center)
                .keyboardType(.decimalPad)
                .focused($quantityFocused)
                .padding(.horizontal, 15)
                .frame(height: 42)
                .background(.white, in: Capsule())
                .overlay(Capsule().stroke(AppStyle.line, lineWidth: 0.8))
                .padding(.top, 18)

            VStack(alignment: .leading, spacing: 10) {
                Text("Einheit")
                    .font(.system(size: 18, design: .monospaced))
                LeftAlignedFlowLayout(horizontalSpacing: 10, verticalSpacing: 12) {
                    ForEach(units, id: \.self) { unit in
                        Button {
                            selectedUnit = unit
                        } label: {
                            SmallOutlinePill(
                                title: unit,
                                fillColor: selectedUnit == unit
                                    ? Color.black.opacity(0.14)
                                    : .white
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer(minLength: 12)
            IngredientColorPicker(selectedIndex: $selectedColorIndex)
            Spacer(minLength: 12)

            OrangeCircleButton(symbol: "checkmark", size: 60) {
                onConfirm(
                    quantity.trimmingCharacters(in: .whitespacesAndNewlines),
                    selectedUnit,
                    selectedColorIndex
                )
                dismiss()
            }
            .padding(.bottom, 14)
        }
        .padding(.horizontal, AppStyle.horizontalPadding)
        .background(.white)
        .onAppear {
            quantityFocused = true
        }
    }
}

// MARK: - Recipe list row and detail

struct RecipeRow: View {
    let recipe: Recipe

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let imageData = recipe.imageData, let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(AppStyle.orange.opacity(0.75))
                        .overlay(
                            Image(systemName: "birthday.cake")
                                .font(.system(size: 42))
                                .foregroundStyle(.black.opacity(0.65))
                        )
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .clipped()

            Text(recipe.title)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(.black)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.white, in: Capsule())
                .overlay(Capsule().stroke(AppStyle.line, lineWidth: 0.7))
                .padding(10)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .contentShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct RecipeDetailView: View {
    let recipe: Recipe
    @EnvironmentObject private var store: RecipeStore
    @Environment(\.dismiss) private var dismiss

    private var currentRecipe: Recipe {
        store.recipes.first(where: { $0.id == recipe.id }) ?? recipe
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    CircleIconButton(symbol: "chevron.left") { dismiss() }
                    Text(currentRecipe.title)
                        .font(AppStyle.heading())
                        .lineLimit(2)
                    Spacer()
                    NavigationLink {
                        RecipeFormView(existingRecipe: currentRecipe)
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 17))
                            .foregroundStyle(.black)
                            .frame(width: 41, height: 41)
                            .background(Circle().fill(.white))
                            .overlay(Circle().stroke(AppStyle.line, lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Rezept bearbeiten")
                }
                .padding(.top, 22)

                if let imageData = currentRecipe.imageData, let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 220)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }

                LeftAlignedFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(store.categories(forRecipeID: currentRecipe.id), id: \.self) { categoryName in
                        SmallOutlinePill(
                            title: categoryName,
                            fillColor: AppStyle.color(for: store.categoryColorIndex(for: categoryName))
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if !currentRecipe.ingredients.isEmpty {
                    Text("Zutaten")
                        .font(.system(size: 21, design: .monospaced))
                    LeftAlignedFlowLayout(horizontalSpacing: 10, verticalSpacing: 10) {
                        ForEach(currentRecipe.ingredients) { item in
                            IngredientPill(
                                title: item.displayText,
                                fillColor: AppStyle.color(for: item.colorIndex).opacity(0.72),
                                fontSize: 16
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !currentRecipe.instructions.isEmpty {
                    Text("Zubereitung")
                        .font(.system(size: 21, design: .monospaced))
                        .padding(.top, 6)
                    ForEach(Array(currentRecipe.instructions.enumerated()), id: \.offset) { index, item in
                        VStack(alignment: .leading, spacing: 14) {
                            Text(item)
                                .font(.system(size: 16, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if index < currentRecipe.instructions.count - 1 {
                                Rectangle()
                                    .fill(AppStyle.line.opacity(0.75))
                                    .frame(height: 0.7)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppStyle.horizontalPadding)
            .padding(.bottom, 30)
        }
        .background(.white)
        .onChange(of: store.recipes) { _, updatedRecipes in
            if !updatedRecipes.contains(where: { $0.id == recipe.id }) {
                dismiss()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    ContentView()
        .environmentObject(RecipeStore())
}
