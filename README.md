# ReadMe

### Leitidee

Schnelle Eingabe von Rezepten: Ein Rezept lässt sich mit wenigen Eingaben schnell anlegen.  _Einfaches Organisieren: Kategorien und Bilder machen das persönliche Rezeptbuch übersichtlich. 
_Rezepte sofort wiederfinden: Rezepte lassen sich über Titel, Kategorien und optional Zutatenfilter entdecken.

### Funktionsumfang

**Priorität 1_MVP**

Diese Funktionen bilden die Grundlage der ersten funktionsfähigen Version.
_Rezeptverwaltung: Rezepte erstellen, anzeigen, bearbeiten und löschen.
_Schnelle Zutatenwahl: Zutaten aus einer vorgefertigten Auswahl über Icons oder Symbole auswählen können, zum Beispiel Mehl, Zucker, Eier oder Butter.
_Zutatensuche und Vorschläge: Zutaten über eine Suchleiste finden oder aus häufig verwendeten Zutaten auswählen können.
_Flexible Zutatenangaben: Mengen und Einheiten direkt ergänzen, bearbeiten oder weglassen können.
_Eigene Zutaten hinzufügen: Zutaten, die nicht in der vorgegebenen Auswahl vorhanden sind, müssen frei eingetragen werden können.
_Lokale Speicherung: Rezepte, Zutaten, Kategorien und Bilder bleiben lokal auf dem Gerät erhalten.
_Zubereitungsschritte: Einzelne Schritte hinzufügen, bearbeiten und löschen können.
_Bilder: Ein Titelbild pro Rezept hinzufügen und austauschen können.
 
**Priorität 2_Sinnvolle Erweiterungen**
_Kategorien: Eigene Kategorien erstellen, bearbeiten und Rezepte diesen zuweisen oder zwischen ihnen verschieben können.
_Rezeptübersicht: Gespeicherte Rezepte übersichtlich darstellen und nach Titel durchsuchen können.
_Zusätzliche Bilder für einzelne Zubereitungsschritte
_Zutatenfilter, um Rezepte anhand vorhandener Zutaten zu finden
_Favoriten und Sortiermöglichkeiten
_Häufig verwendete oder zuletzt ausgewählte Zutaten automatisch vorschlagen
_Zutatenmengen an unterschiedliche Portionsgrößen anpassen

### Entwicklungsplan

**Planung und Datenmodell**

- Anforderungen und Muss-Funktionen festlegen.
- Datenstruktur für Rezepte, Zutaten, Zubereitungsschritte und Kategorien planen.
- Eine erste Liste mit vorgefertigten Zutaten erstellen.
- Festlegen, wie Zutaten-Icons und Mengenangaben miteinander verknüpft werden.
- Zielplattform und technische Grundlage bestimmen.

**Benutzeroberfläche gestalten**

- Rezeptübersicht und Rezeptdetailansicht entwerfen.
- Formular zum Erstellen und Bearbeiten von Rezepten gestalten.
- Zutaten-Auswahl mit Icons, Beschriftungen und Suchfeld entwickeln.
- Schaltflächen für das Hinzufügen eigener Zutaten vorsehen.
- Kategorien und Bildauswahl in die Bedienung integrieren.

**Lokale Speicherung einrichten**

- Lokale Datenbank und Speicherung konfigurieren.
- Rezeptdaten und Zutatenlisten miteinander verknüpfen.
- Vorgefertigte Zutaten samt Namen, Kategorien und Icon-Zuordnung hinterlegen.
- Eigene Zutaten speichern können.
- Speicherung von Bildern und Dateiverweisen umsetzen.

**Schnelle Rezepteingabe entwickeln**

- Zutaten-Auswahl über vorgefertigte Icons und Symbole implementieren.
- Häufige Zutaten direkt sichtbar anbieten.
- Such- und Vorschlagsfunktion für die Zutatenliste ergänzen.
- Mengen und Einheiten direkt bei der ausgewählten Zutat eingeben.
- Neue Zutaten und individuelle Angaben jederzeit ermöglichen.
- Zubereitungsschritte hinzufügen, bearbeiten und löschen.
- Rezepte erstellen, speichern und nachträglich bearbeiten.

**Kategorien und Bilder integrieren**

- Kategorien anlegen, umbenennen und verwalten.
- Rezepte Kategorien zuordnen und verschieben.
- Titelbilder auswählen, ändern und entfernen.
- Optional zusätzliche Bilder für die Zubereitungsschritte ermöglichen.
Ergebnis: Die Rezepte können individuell organisiert und bebildert werden.

**Suche und optionale Filter**

- Rezepte nach Titel durchsuchen.
- Nach Kategorien filtern.
- Falls ausreichend Zeit vorhanden ist: Zutaten auswählen und passende Rezepte anzeigen lassen.
- Festlegen, ob Rezepte alle oder nur einige der ausgewählten Zutaten enthalten müssen.

**Testen und Fertigstellen**

- Zutaten-Auswahl, Vorschläge und freie Eingaben testen.
- Speichern, Bearbeiten und Löschen überprüfen.
- Bildverwaltung und Kategorien kontrollieren.
- Verhalten bei fehlenden Angaben und ungültigen Mengen testen.
- Datenbeständigkeit nach einem Neustart überprüfen.
- Fehler beheben und die Anwendung finalisieren.

### Thema Programmierung

_Swift – Programmiersprache
_SwiftUI – Benutzeroberfläche (Framework)
_SwiftData – lokale Datenbank
_PhotosUI – Bilder auswählen (PhotoPicker)
_Xcode – Anwendung, Coding

**möglicher Aufbau der Dateien**

RecipeBook/
├── RecipeBookApp.swift
├── Models/
│   ├── Recipe.swift
│   ├── Ingredient.swift
│   ├── RecipeStep.swift
│   └── RecipeCategory.swift
├── Views/
│   ├── RecipeListView.swift
│   ├── RecipeDetailView.swift
│   ├── RecipeEditorView.swift
│   ├── IngredientPickerView.swift
│   └── CategoryView.swift
├── Services/
│   └── ImageStorageService.swift
└── Assets.xcassets



