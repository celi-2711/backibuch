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

/// A recipe ingredient is stored as structured data instead of a plain string.
/// This allows the app to remember amount, unit and the selected color.
struct RecipeIngredient: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var amount: String
    var colorIndex: Int

    init(id: UUID = UUID(), name: String, amount: String = "", colorIndex: Int = 1) {
        self.id = id
        self.name = name
        self.amount = amount
        self.colorIndex = colorIndex
    }

    var displayText: String {
        amount.isEmpty ? name : "\(amount)  \(name)"
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

    @Published var ingredientCatalog: [String] = RecipeStore.defaultIngredients {
        didSet { save(ingredientCatalog, forKey: Self.ingredientsKey) }
    }

    private static let recipesKey = "rezeptapp.recipes.v1"
    private static let categoriesKey = "rezeptapp.categories.v1"
    private static let ingredientsKey = "rezeptapp.ingredientCatalog.v1"

    static let defaultCategories = [
        "Hefeteig", "Rührkuchen", "Tarte", "Muffins", "Kekse", "Torten",
        "Plunder", "Tartelette", "Weihnachten", "Cremes", "No-Bake",
        "Blätterteig", "Pralinen", "Sonstiges"
    ]

    static let defaultIngredients = [
        "Mehl", "Zucker", "Butter", "Ei", "Milch", "Salz", "Zimt",
        "Vanillezucker", "Wasser", "brauner Zucker", "Apfel", "Zitronensaft",
        "Vanille", "Blaubeeren", "Hefe", "Puderzucker", "Mandeln", "Zartbitter",
        "Vollmilch", "Saft", "Sahne", "Mascarpone", "Joghurt", "Magerquark",
        "Himbeeren", "Buttermilch", "Eigelb", "Espresso", "Nougat", "Haferkekse",
        "Marmelade", "Biskuit"
    ]

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

        if let data = UserDefaults.standard.data(forKey: Self.ingredientsKey),
           let savedIngredients = try? JSONDecoder().decode([String].self, from: data),
           !savedIngredients.isEmpty {
            ingredientCatalog = savedIngredients
        }
    }

    func addRecipe(_ recipe: Recipe) {
        recipes.insert(recipe, at: 0)
    }

    func updateRecipe(_ recipe: Recipe) {
        guard let index = recipes.firstIndex(where: { $0.id == recipe.id }) else { return }
        recipes[index] = recipe
    }

    func addCategory(_ name: String) {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty else { return }
        guard !categories.contains(where: {
            $0.localizedCaseInsensitiveCompare(cleanedName) == .orderedSame
        }) else { return }
        categories.append(cleanedName)
    }

    func addIngredient(_ name: String) {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty else { return }
        guard !ingredientCatalog.contains(where: {
            $0.localizedCaseInsensitiveCompare(cleanedName) == .orderedSame
        }) else { return }
        ingredientCatalog.append(cleanedName)
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

    static let ingredientColors: [Color] = [
        Color(red: 1.00, green: 0.70, blue: 0.29), // orange
        Color(red: 1.00, green: 0.94, blue: 0.58), // yellow
        Color(red: 1.00, green: 0.62, blue: 0.68), // pink
        Color(red: 0.48, green: 0.85, blue: 0.94), // turquoise
        Color(red: 0.27, green: 0.66, blue: 0.94), // blue
        Color(red: 0.87, green: 0.48, blue: 0.91), // purple
        Color(red: 1.00, green: 0.32, blue: 0.37)  // red
    ]

    static func color(for index: Int) -> Color {
        ingredientColors[index % ingredientColors.count]
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

    var body: some View {
        Text(title)
            .font(AppStyle.pillText())
            .foregroundStyle(.black)
            .padding(.horizontal, 19)
            .padding(.vertical, 10)
            .background(filled ? AppStyle.orange : .white, in: Capsule())
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
        HStack(spacing: 12) {
            ForEach(AppStyle.ingredientColors.indices, id: \.self) { index in
                Button {
                    selectedIndex = index
                } label: {
                    Circle()
                        .fill(AppStyle.color(for: index))
                        .frame(width: 39, height: 39)
                        .overlay(
                            Circle().stroke(
                                selectedIndex == index ? Color.black.opacity(0.75) : Color.black.opacity(0.25),
                                lineWidth: selectedIndex == index ? 1.3 : 0.6
                            )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Farbe \(index + 1)")
            }
        }
        .frame(maxWidth: .infinity)
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
            $0.category.localizedCaseInsensitiveContains(searchText) ||
            $0.ingredients.contains(where: {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.amount.localizedCaseInsensitiveContains(searchText)
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
    @State private var showingAddCategory = false
    @State private var newCategoryName = ""

    private var searchResults: [Recipe] {
        guard !searchText.isEmpty else { return [] }
        return store.recipes.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.category.localizedCaseInsensitiveContains(searchText) ||
            $0.ingredients.contains(where: { $0.name.localizedCaseInsensitiveContains(searchText) }) ||
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
                                OutlinePill(title: category)
                            }
                            .buttonStyle(.plain)
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
                    newCategoryName = ""
                    showingAddCategory = true
                }
                .padding(.trailing, 20)
                .padding(.bottom, 18)
            }
        }
        .alert("Neue Kategorie", isPresented: $showingAddCategory) {
            TextField("Name der Kategorie", text: $newCategoryName)
            Button("Hinzufügen") { store.addCategory(newCategoryName) }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Gib deiner neuen Kategorie einen Namen.")
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

// MARK: - Category results

struct CategoryRecipesView: View {
    let category: String
    @EnvironmentObject private var store: RecipeStore
    @Environment(\.dismiss) private var dismiss

    private var recipes: [Recipe] {
        store.recipes.filter { $0.category == category }
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
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
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
    @State private var showingIngredientPicker = false
    @FocusState private var titleFieldFocused: Bool

    init(existingRecipe: Recipe? = nil) {
        self.existingRecipe = existingRecipe
        _title = State(initialValue: existingRecipe?.title ?? "")
        _selectedIngredients = State(initialValue: existingRecipe?.ingredients ?? [])
        _instructionFields = State(initialValue: existingRecipe?.instructions ?? [])
        _selectedCategory = State(initialValue: existingRecipe?.category ?? "")
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
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
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
    @State private var showingAddIngredient = false
    @State private var newIngredientName = ""
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
                        newIngredientName = ""
                        showingAddIngredient = true
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
                                    fillColor: isSelected(name) ? Color.black.opacity(0.17) : .white
                                )
                            }
                            .buttonStyle(.plain)
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
            .alert("Neue Zutat", isPresented: $showingAddIngredient) {
                TextField("Name der Zutat", text: $newIngredientName)
                Button("Hinzufügen") { store.addIngredient(newIngredientName) }
                Button("Abbrechen", role: .cancel) { }
            } message: {
                Text("Die Zutat wird dauerhaft in deiner Zutatenliste gespeichert.")
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
}

// MARK: - Ingredient amount and color screen (Zutaten_02.png)

struct IngredientAmountView: View {
    let name: String
    let existingIngredient: RecipeIngredient?
    let onSave: (RecipeIngredient) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amount: String
    @State private var selectedColorIndex: Int
    @State private var showingManualEntry = false

    init(
        name: String,
        existingIngredient: RecipeIngredient? = nil,
        onSave: @escaping (RecipeIngredient) -> Void
    ) {
        self.name = name
        self.existingIngredient = existingIngredient
        self.onSave = onSave
        _amount = State(initialValue: existingIngredient?.amount ?? "")
        _selectedColorIndex = State(initialValue: existingIngredient?.colorIndex ?? 1)
    }

    private let amountSuggestions = ["500 g", "450 g", "250 g", "125 g", "100 g", "300 g", "50 g", "1 kg"]
    private let flourTypeSuggestions = ["t 405", "t 550", "t 1050"]
    private let standardSuggestions = ["50 g", "100 g", "125 g", "250 g", "500 g", "1 kg", "1 EL", "1 TL"]

    private var isFlour: Bool {
        name.localizedCaseInsensitiveCompare("Mehl") == .orderedSame
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Zutaten")
                    .font(AppStyle.heading())
                    .foregroundStyle(.black)
                Spacer()
                CircleIconButton(symbol: "xmark") { dismiss() }
            }
            .padding(.top, 22)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    SmallOutlinePill(
                        title: name,
                        fillColor: AppStyle.color(for: selectedColorIndex).opacity(0.55)
                    )
                    .padding(.top, 20)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 3), alignment: .leading, spacing: 18) {
                        ForEach(isFlour ? amountSuggestions : standardSuggestions, id: \.self) { suggestion in
                            suggestionButton(suggestion)
                        }
                    }
                    .padding(.top, 22)

                    if isFlour {
                        HStack(spacing: 10) {
                            ForEach(flourTypeSuggestions, id: \.self) { suggestion in
                                suggestionButton(suggestion)
                            }
                        }
                        .padding(.top, 76)
                    } else {
                        Spacer(minLength: 75)
                    }

                    IngredientColorPicker(selectedIndex: $selectedColorIndex)
                        .padding(.top, isFlour ? 78 : 70)

                    Button {
                        showingManualEntry = true
                    } label: {
                        SmallOutlinePill(title: "Eingabe")
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 78)
                    .padding(.bottom, 30)
                }
            }

            OrangeCircleButton(symbol: "checkmark", size: 60) {
                onSave(RecipeIngredient(
                    id: existingIngredient?.id ?? UUID(),
                    name: name,
                    amount: amount.trimmingCharacters(in: .whitespacesAndNewlines),
                    colorIndex: selectedColorIndex
                ))
                dismiss()
            }
            .padding(.top, 10)
            .padding(.bottom, 14)
        }
        .padding(.horizontal, AppStyle.horizontalPadding)
        .background(.white)
        .sheet(isPresented: $showingManualEntry) {
            ManualQuantitySheet(initialValue: amount, initialColorIndex: selectedColorIndex) { newAmount, newColor in
                amount = newAmount
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

    private func suggestionButton(_ suggestion: String) -> some View {
        let isSelected = amount == suggestion
        let fillColor = isSelected
            ? AppStyle.color(for: selectedColorIndex).opacity(0.78)
            : Color.white

        return Button {
            amount = suggestion
        } label: {
            SmallOutlinePill(title: suggestion, fillColor: fillColor)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Manual amount/unit overlay (Zutaten_Eingabe.png)

struct ManualQuantitySheet: View {
    let onConfirm: (String, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var quantity: String
    @State private var selectedUnit: String
    @State private var selectedColorIndex: Int
    @FocusState private var quantityFocused: Bool

    private let units = ["g", "kg", "ml", "l", "el", "tl", "msp", "stck", "pck", "prise"]

    init(initialValue: String, initialColorIndex: Int, onConfirm: @escaping (String, Int) -> Void) {
        let parsed = Self.parseAmount(initialValue)
        self.onConfirm = onConfirm
        _quantity = State(initialValue: parsed.quantity)
        _selectedUnit = State(initialValue: parsed.unit)
        _selectedColorIndex = State(initialValue: initialColorIndex)
    }

    var body: some View {
        VStack(spacing: 20) {
            TextField("Eingabe", text: $quantity)
                .font(.system(size: 21, design: .monospaced))
                .multilineTextAlignment(.center)
                .keyboardType(.decimalPad)
                .focused($quantityFocused)
                .padding(.horizontal, 15)
                .frame(height: 42)
                .background(.white, in: Capsule())
                .overlay(Capsule().stroke(AppStyle.line, lineWidth: 0.8))
                .padding(.top, 18)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 14) {
                ForEach(units, id: \.self) { unit in
                    Button {
                        selectedUnit = unit
                    } label: {
                        SmallOutlinePill(
                            title: unit,
                            fillColor: selectedUnit == unit ? Color.black.opacity(0.13) : .white
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: 12)

            IngredientColorPicker(selectedIndex: $selectedColorIndex)

            Spacer(minLength: 12)

            OrangeCircleButton(symbol: "checkmark", size: 60) {
                let cleanQuantity = quantity.trimmingCharacters(in: .whitespacesAndNewlines)
                let result: String
                if cleanQuantity.isEmpty {
                    result = ""
                } else if selectedUnit.isEmpty {
                    result = cleanQuantity
                } else {
                    result = "\(cleanQuantity) \(selectedUnit)"
                }
                onConfirm(result, selectedColorIndex)
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

    private static func parseAmount(_ value: String) -> (quantity: String, unit: String) {
        let trimmed: String = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized: String = trimmed.lowercased()

        // Explicit type annotation keeps the SwiftUI preview compiler's
        // type-checking work small and predictable.
        let knownUnits: [String] = [
            "stck",
            "prise",
            "msp",
            "pck",
            "kg",
            "ml",
            "el",
            "tl",
            "g",
            "l"
        ]

        // Flour types such as "t 405" are labels, not measured quantities.
        if normalized.hasPrefix("t ") {
            let possibleNumber = normalized.dropFirst(2)
            if !possibleNumber.isEmpty && possibleNumber.allSatisfy({ $0.isNumber }) {
                return (trimmed, "")
            }
        }

        for unit: String in knownUnits {
            let suffix: String = " " + unit
            if normalized.hasSuffix(suffix) {
                let quantityLength = trimmed.count - suffix.count
                if quantityLength >= 0 {
                    let splitIndex = trimmed.index(trimmed.startIndex, offsetBy: quantityLength)
                    let quantity = String(trimmed[..<splitIndex])
                    return (quantity, unit)
                }
            }
        }

        return (trimmed, "g")
    }
}

// MARK: - Recipe list row and detail

struct RecipeRow: View {
    let recipe: Recipe

    var body: some View {
        HStack(spacing: 13) {
            if let imageData = recipe.imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 66, height: 66)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppStyle.orange.opacity(0.75))
                    .frame(width: 66, height: 66)
                    .overlay(Image(systemName: "birthday.cake").font(.system(size: 23)))
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(recipe.title)
                    .font(.system(size: 18, design: .monospaced))
                    .foregroundStyle(.black)
                Text(recipe.category)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.black.opacity(0.55))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.black.opacity(0.55))
        }
        .padding(9)
        .background(.white, in: RoundedRectangle(cornerRadius: 17))
        .overlay(RoundedRectangle(cornerRadius: 17).stroke(AppStyle.line, lineWidth: 0.7))
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

                SmallOutlinePill(title: currentRecipe.category)

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
                        Text("\(index + 1).  \(item)")
                            .font(.system(size: 16, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppStyle.horizontalPadding)
            .padding(.bottom, 30)
        }
        .background(.white)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    ContentView()
        .environmentObject(RecipeStore())
}
