import SwiftUI
import Combine
import PhotosUI
import UIKit

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

struct Recipe: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var imageData: Data?
    var ingredients: [String]
    var instructions: [String]
    var category: String
}


@MainActor
final class RecipeStore: ObservableObject {

    // MARK: - Standardwerte

    private static let recipesKey = "rezeptapp.recipes.v1"
    private static let categoriesKey = "rezeptapp.categories.v1"

    static let defaultCategories = [
        "Hefeteig",
        "Rührkuchen",
        "Tarte",
        "Muffins",
        "Kekse",
        "Torten",
        "Plunder",
        "Tartelette",
        "Weihnachten",
        "Cremes",
        "No-Bake",
        "Blätterteig",
        "Pralinen",
        "Sonstiges"
    ]

    // MARK: - Gespeicherte Daten

    @Published var recipes: [Recipe] = [] {
        didSet {
            save(recipes, forKey: Self.recipesKey)
        }
    }

    @Published var categories: [String] = RecipeStore.defaultCategories {
        didSet {
            save(categories, forKey: Self.categoriesKey)
        }
    }

    // MARK: - Initialisierung

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
    }

    // MARK: - Rezepte hinzufügen

    func addRecipe(_ recipe: Recipe) {
        recipes.insert(recipe, at: 0)
    }

    // MARK: - Kategorien hinzufügen

    func addCategory(_ name: String) {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanedName.isEmpty else { return }

        guard !categories.contains(where: {
            $0.localizedCaseInsensitiveCompare(cleanedName) == .orderedSame
        }) else { return }

        categories.append(cleanedName)
    }

    // MARK: - Daten speichern

    private func save<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else {
            return
        }

        UserDefaults.standard.set(data, forKey: key)
    }
}


// MARK: - Shared styling

private enum AppStyle {
    static let orange = Color(red: 1.00, green: 0.70, blue: 0.29)
    static let ink = Color.black.opacity(0.82)
    static let line = Color.black.opacity(0.62)
    static let horizontalPadding: CGFloat = 20

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
        .accessibilityLabel(symbol == "magnifyingglass" ? "Suche öffnen" : "Schließen")
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

    var body: some View {
        Text(title)
            .font(.system(size: 19, weight: .regular, design: .monospaced))
            .foregroundStyle(.black)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(.white, in: Capsule())
            .overlay(Capsule().stroke(AppStyle.line, lineWidth: 0.8))
            .fixedSize(horizontal: true, vertical: false)
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
            $0.ingredients.contains(where: { $0.localizedCaseInsensitiveContains(searchText) }) ||
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
    @State private var isSearching = false
    @State private var searchText = ""
    @State private var showingAddCategory = false
    @State private var newCategoryName = ""

    private var searchResults: [Recipe] {
        guard !searchText.isEmpty else { return [] }
        return store.recipes.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.category.localizedCaseInsensitiveContains(searchText) ||
            $0.ingredients.contains(where: { $0.localizedCaseInsensitiveContains(searchText) }) ||
            $0.instructions.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
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
            Button("Hinzufügen") {
                store.addCategory(newCategoryName)
            }
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

// MARK: - Screen 02: create recipe

struct RecipeFormView: View {
    @EnvironmentObject private var store: RecipeStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var ingredientFields: [String] = []
    @State private var instructionFields: [String] = []
    @State private var selectedCategory = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var showingTitleAlert = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Neues Rezept")
                    .font(AppStyle.heading())
                    .foregroundStyle(.black)
                Spacer()
                CircleIconButton(symbol: "xmark") {
                    dismiss()
                }
            }
            .padding(.top, 22)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    TextField("Titel", text: $title)
                        .font(.system(size: 20, weight: .regular, design: .monospaced))
                        .padding(.horizontal, 15)
                        .frame(height: 40)
                        .background(.white, in: Capsule())
                        .overlay(Capsule().stroke(AppStyle.line, lineWidth: 0.8))
                        .padding(.top, 20)

                    photoPicker

                    formSection(title: "Zutaten", fields: $ingredientFields, placeholder: "Zutat eingeben", isMultiline: false)
                    formSection(title: "Zubereitung", fields: $instructionFields, placeholder: "Schritt beschreiben", isMultiline: true)

                    Menu {
                        ForEach(store.categories, id: \.self) { category in
                            Button(category) {
                                selectedCategory = category
                            }
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
        .onChange(of: selectedPhoto) { _, newPhoto in
            guard let newPhoto else { return }
            Task {
                if let data = try? await newPhoto.loadTransferable(type: Data.self) {
                    imageData = Self.optimizedImageData(from: data) ?? data
                }
            }
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

    @ViewBuilder
    private func formSection(
        title: String,
        fields: Binding<[String]>,
        placeholder: String,
        isMultiline: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                SmallOutlinePill(title: title)
                Button {
                    fields.wrappedValue.append("")
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.black)
                        .frame(width: 40, height: 40)
                        .background(.white, in: Circle())
                        .overlay(Circle().stroke(AppStyle.line, lineWidth: 0.8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(title) hinzufügen")
            }

            ForEach(fields.wrappedValue.indices, id: \.self) { index in
                HStack(alignment: isMultiline ? .top : .center, spacing: 8) {
                    Group {
                        if isMultiline {
                            TextField(placeholder, text: fields[index], axis: .vertical)
                                .lineLimit(2...5)
                        } else {
                            TextField(placeholder, text: fields[index])
                        }
                    }
                    .font(.system(size: 15, design: .monospaced))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white, in: RoundedRectangle(cornerRadius: 13))
                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(AppStyle.line, lineWidth: 0.7))

                    Button {
                        fields.wrappedValue.remove(at: index)
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 20))
                            .foregroundStyle(.black.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
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
            title: cleanedTitle,
            imageData: imageData,
            ingredients: ingredientFields.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty },
            instructions: instructionFields.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty },
            category: selectedCategory.isEmpty ? "Sonstiges" : selectedCategory
        )
        store.addRecipe(recipe)
        dismiss()
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
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    CircleIconButton(symbol: "chevron.left") { dismiss() }
                    Text(recipe.title)
                        .font(AppStyle.heading())
                        .lineLimit(2)
                    Spacer()
                }
                .padding(.top, 22)

                if let imageData = recipe.imageData, let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 220)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }

                SmallOutlinePill(title: recipe.category)

                if !recipe.ingredients.isEmpty {
                    Text("Zutaten")
                        .font(.system(size: 21, design: .monospaced))
                    ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { _, item in
                        Text("•  \(item)")
                            .font(.system(size: 16, design: .monospaced))
                    }
                }

                if !recipe.instructions.isEmpty {
                    Text("Zubereitung")
                        .font(.system(size: 21, design: .monospaced))
                        .padding(.top, 6)
                    ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { index, item in
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
