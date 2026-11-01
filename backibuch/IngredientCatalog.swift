import Foundation

/// Zentrale, im Code gepflegte Definition einer Zutat.
/// Hier werden die Mengen-, Einheiten- und Zusatzvorschläge für jede Zutat festgelegt.
struct IngredientDefinition: Identifiable, Codable, Equatable {
    /// Stabile Kennung. Beim Umbenennen der Zutat möglichst unverändert lassen.
    var id: String
    var name: String
    var quantitySuggestions: [String]
    var unitSuggestions: [String]
    var modifierSuggestions: [String]

    init(
        id: String,
        name: String,
        quantitySuggestions: [String],
        unitSuggestions: [String],
        modifierSuggestions: [String] = []
    ) {
        self.id = id
        self.name = name
        self.quantitySuggestions = quantitySuggestions
        self.unitSuggestions = unitSuggestions
        self.modifierSuggestions = modifierSuggestions
    }
}

/// Zentrale Zutaten-Datenbank.
/// Neue Zutaten werden hier ergänzt; die Reihenfolge entspricht der Anzeige in der App.
enum IngredientCatalog {
    static let fallbackQuantitySuggestions = [
        "1", "2", "3", "4", "5", "10", "25", "50", "100", "125", "250", "500"
    ]

    static let fallbackUnitSuggestions = [
        "g", "kg", "ml", "l", "EL", "TL", "Msp", "Stück", "Pck", "Prise"
    ]

    static let definitions: [IngredientDefinition] = [
        IngredientDefinition(
            id: "mehl", name: "Mehl",
            quantitySuggestions: ["50", "100", "125", "200", "250", "300", "450", "500", "1000"],
            unitSuggestions: ["g", "kg"],
            modifierSuggestions: ["Type 405", "Type 550", "Type 1050", "Vollkorn", "Dinkel"]
        ),
        IngredientDefinition(
            id: "zucker", name: "Zucker",
            quantitySuggestions: ["25", "50", "75", "100", "125", "150", "200", "250", "500"],
            unitSuggestions: ["g", "kg"]
        ),
        IngredientDefinition(
            id: "butter", name: "Butter",
            quantitySuggestions: ["25", "50", "75", "100", "125", "150", "200", "250", "500"],
            unitSuggestions: ["g", "kg"],
            modifierSuggestions: ["weich", "kalt", "geschmolzen"]
        ),
        IngredientDefinition(
            id: "ei", name: "Ei",
            quantitySuggestions: ["1", "2", "3", "4", "5", "6", "8", "10"],
            unitSuggestions: ["Stück"],
            modifierSuggestions: ["Größe S", "Größe M", "Größe L", "getrennt"]
        ),
        IngredientDefinition(
            id: "milch", name: "Milch",
            quantitySuggestions: ["25", "50", "100", "125", "150", "200", "250", "500", "750", "1000"],
            unitSuggestions: ["ml", "l"]
        ),
        IngredientDefinition(
            id: "salz", name: "Salz",
            quantitySuggestions: ["1", "2", "3", "5", "10", "15"],
            unitSuggestions: ["Prise", "Msp", "g", "TL"]
        ),
        IngredientDefinition(
            id: "zimt", name: "Zimt",
            quantitySuggestions: ["1", "2", "3", "4", "5", "10"],
            unitSuggestions: ["TL", "Msp", "g"]
        ),
        IngredientDefinition(
            id: "vanillezucker", name: "Vanillezucker",
            quantitySuggestions: ["1", "2", "3", "4", "5"],
            unitSuggestions: ["Pck", "EL", "g"]
        ),
        IngredientDefinition(
            id: "wasser", name: "Wasser",
            quantitySuggestions: ["25", "50", "100", "125", "150", "200", "250", "500", "750", "1000"],
            unitSuggestions: ["ml", "l"]
        ),
        IngredientDefinition(
            id: "brauner-zucker", name: "brauner Zucker",
            quantitySuggestions: ["25", "50", "75", "100", "125", "150", "200", "250", "500"],
            unitSuggestions: ["g", "kg"]
        ),
        IngredientDefinition(
            id: "apfel", name: "Apfel",
            quantitySuggestions: ["1", "2", "3", "4", "5", "6"],
            unitSuggestions: ["Stück", "g"],
            modifierSuggestions: ["gerieben", "gewürfelt", "in Spalten", "geschält"]
        ),
        IngredientDefinition(
            id: "zitronensaft", name: "Zitronensaft",
            quantitySuggestions: ["1", "2", "3", "4", "5", "10", "15"],
            unitSuggestions: ["EL", "TL", "ml"]
        ),
        IngredientDefinition(
            id: "vanille", name: "Vanille",
            quantitySuggestions: ["1/2", "1", "2"],
            unitSuggestions: ["Stück", "TL", "Msp"],
            modifierSuggestions: ["Mark einer Schote", "Extrakt"]
        ),
        IngredientDefinition(
            id: "blaubeeren", name: "Blaubeeren",
            quantitySuggestions: ["25", "50", "75", "100", "125", "150", "200", "250", "300"],
            unitSuggestions: ["g", "kg"],
            modifierSuggestions: ["frisch", "tiefgekühlt"]
        ),
        IngredientDefinition(
            id: "hefe", name: "Hefe",
            quantitySuggestions: ["1/2", "1", "2"],
            unitSuggestions: ["Würfel", "Pck", "g"],
            modifierSuggestions: ["frisch", "trocken"]
        ),
        IngredientDefinition(
            id: "puderzucker", name: "Puderzucker",
            quantitySuggestions: ["25", "50", "75", "100", "125", "150", "200", "250"],
            unitSuggestions: ["g", "kg"]
        ),
        IngredientDefinition(
            id: "mandeln", name: "Mandeln",
            quantitySuggestions: ["25", "50", "75", "100", "125", "150", "200", "250"],
            unitSuggestions: ["g", "kg"],
            modifierSuggestions: ["gemahlen", "gehackt", "gehobelt", "blanchiert"]
        ),
        IngredientDefinition(
            id: "zartbitter", name: "Zartbitter",
            quantitySuggestions: ["25", "50", "75", "100", "125", "150", "200", "250"],
            unitSuggestions: ["g", "kg"],
            modifierSuggestions: ["gehackt", "geraspelt", "geschmolzen", "Tropfen"]
        ),
        IngredientDefinition(
            id: "vollmilch", name: "Vollmilch",
            quantitySuggestions: ["25", "50", "100", "125", "150", "200", "250", "500"],
            unitSuggestions: ["g", "ml", "l"]
        ),
        IngredientDefinition(
            id: "saft", name: "Saft",
            quantitySuggestions: ["25", "50", "100", "125", "150", "200", "250", "500"],
            unitSuggestions: ["ml", "l", "EL"]
        ),
        IngredientDefinition(
            id: "sahne", name: "Sahne",
            quantitySuggestions: ["50", "100", "125", "150", "200", "250", "500"],
            unitSuggestions: ["ml", "l", "g"],
            modifierSuggestions: ["flüssig", "geschlagen"]
        ),
        IngredientDefinition(
            id: "mascarpone", name: "Mascarpone",
            quantitySuggestions: ["50", "100", "125", "150", "200", "250", "500"],
            unitSuggestions: ["g", "kg"]
        ),
        IngredientDefinition(
            id: "joghurt", name: "Joghurt",
            quantitySuggestions: ["50", "100", "125", "150", "200", "250", "500"],
            unitSuggestions: ["g", "kg"],
            modifierSuggestions: ["natur", "griechisch"]
        ),
        IngredientDefinition(
            id: "magerquark", name: "Magerquark",
            quantitySuggestions: ["50", "100", "125", "150", "200", "250", "500", "1000"],
            unitSuggestions: ["g", "kg"]
        ),
        IngredientDefinition(
            id: "himbeeren", name: "Himbeeren",
            quantitySuggestions: ["25", "50", "75", "100", "125", "150", "200", "250", "300"],
            unitSuggestions: ["g", "kg"],
            modifierSuggestions: ["frisch", "tiefgekühlt"]
        ),
        IngredientDefinition(
            id: "buttermilch", name: "Buttermilch",
            quantitySuggestions: ["50", "100", "125", "150", "200", "250", "500", "1000"],
            unitSuggestions: ["ml", "l"]
        ),
        IngredientDefinition(
            id: "eigelb", name: "Eigelb",
            quantitySuggestions: ["1", "2", "3", "4", "5", "6"],
            unitSuggestions: ["Stück"]
        ),
        IngredientDefinition(
            id: "espresso", name: "Espresso",
            quantitySuggestions: ["1", "2", "3", "4"],
            unitSuggestions: ["Tasse", "Shot", "ml"]
        ),
        IngredientDefinition(
            id: "nougat", name: "Nougat",
            quantitySuggestions: ["25", "50", "75", "100", "125", "150", "200", "250"],
            unitSuggestions: ["g", "kg"],
            modifierSuggestions: ["weich", "gehackt", "geschmolzen"]
        ),
        IngredientDefinition(
            id: "haferkekse", name: "Haferkekse",
            quantitySuggestions: ["1", "2", "3", "4", "5", "100", "150", "200"],
            unitSuggestions: ["Stück", "g"],
            modifierSuggestions: ["zerkrümelt", "grob zerstoßen"]
        ),
        IngredientDefinition(
            id: "marmelade", name: "Marmelade",
            quantitySuggestions: ["1", "2", "3", "4", "5", "50", "100", "150"],
            unitSuggestions: ["EL", "TL", "g"],
            modifierSuggestions: ["Aprikose", "Erdbeere", "Himbeere"]
        ),
        IngredientDefinition(
            id: "biskuit", name: "Biskuit",
            quantitySuggestions: ["1", "2", "3", "4", "100", "150", "200"],
            unitSuggestions: ["Stück", "g"],
            modifierSuggestions: ["zerkrümelt", "gebacken"]
        )
    ]

    static func definition(for ingredientName: String) -> IngredientDefinition? {
        definitions.first {
            $0.name.localizedCaseInsensitiveCompare(ingredientName) == .orderedSame
        }
    }
}
