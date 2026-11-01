# AI_Usage

**Briefing_Arbeitsplan**

_Erstellung von Projektbrief
_Zusammenfassung was gemacht werden muss

## Coding der App

**Grundaufbau, erste 3 Screens**
Entwicklung der Startseite, des Backbuchs mit Kategorien und des Screens zum Erstellen neuer Rezepte. Umsetzung der Navigation zwischen den Bereichen sowie der Suchfunktion.
**Probleme und Fehleranalyse:** Bei der ersten Umsetzung gab es Schwierigkeiten mit der ObservableObject-Klasse und den @Published-Variablen. Durch Anpassungen der Initialisierungen und die korrekte Verwendung von Combine wurde die Datenverwaltung stabilisiert.

**Rezept erstellen und bearbeiten**
Aufbau des Rezeptformulars mit Titel, Bildauswahl, Zutaten und Zubereitung. Ergänzung der Funktionen zum Speichern, Bearbeiten und Löschen von Rezepten.
**Probleme und Fehleranalyse:** Beim Erweitern des Rezeptmodells mussten bestehende Daten berücksichtigt werden. Deshalb wurde eine Datenmigration ergänzt, damit bereits gespeicherte Rezepte weiterhin geladen werden können.

**Zutaten-Auswahl und Mengenangaben**
Entwicklung eines eigenen Zutaten-Overlays mit vordefinierten Zutaten. Ergänzung einer Detailansicht, in der Menge, Einheit, optionaler Zusatz und Farbe ausgewählt werden können. Zusätzlich wurde eine manuelle Mengen- und Einheitseingabe integriert.
**Probleme und Fehleranalyse:** Die Mengenerkennung verursachte einen Compilerfehler, weil Swift einen längeren Ausdruck nicht rechtzeitig typisieren konnte. Die Funktion parseAmount() wurde deshalb in kleinere Schritte aufgeteilt und die Mengeneinheiten wurden ausdrücklich als [String] definiert.

**Zutaten-Darstellung im Rezept**
Anpassung der Zutatenbuttons: linksbündige Anordnung, flexible Buttonbreiten und gleichmäßige Abstände. Ausgewählte Zutaten werden farblich hervorgehoben und später als farbige Pills im Rezept dargestellt.
**Probleme und Fehleranalyse:** Das ursprüngliche starre LazyVGrid führte zu einer ungewünschten Darstellung. Es wurde durch ein flexibles Flow-Layout ersetzt. Außerdem fehlte nach einer früheren Designänderung die sichtbare Markierung ausgewählter Mengen. Dafür wurde eine dezente graue Hinterlegung eingeführt.

**Rezeptansicht und Rezeptübersicht**
Umsetzung einer Rezeptdetailseite mit Zutaten und getrennten Zubereitungsabschnitten ohne Nummerierung. Anpassung der Rezeptübersichten in Kategorien und Suche auf große Bildkarten mit abgerundeten Ecken und Titel-Capsules.
**Probleme und Fehleranalyse:** Bei der Umstellung mussten die bisherigen Rezeptdaten und Darstellungsformen berücksichtigt werden. Die Rezeptübersicht wurde deshalb angepasst, ohne die bestehende Speicherstruktur unnötig zu verändern.

**Kategorienverwaltung**
Möglichkeit, eigene Kategorien hinzuzufügen, umzubenennen, zu löschen und optional einzufärben. Ergänzung einer Funktion, mit der bereits vorhandene Rezepte einer Kategorie zugeordnet werden können. Ausgewählte Rezepte werden durch kleine Punkte gekennzeichnet.
**Probleme und Fehleranalyse:** Bei der Verwendung von AppStyle.whiteColorIndex als Standardwert traten gelbe Markierungen im Code auf. Die Standardwerte wurden angepasst, sodass Weiß weiterhin als neutraler Zustand verwendet wird.

**Zentrale Zutaten-Datenbank**
Auslagerung der Zutaten in eine eigene Swift-Datei (IngredientCatalog.swift). Jede Zutat erhält individuelle Mengen-Vorschläge, Einheiten und Zusätze. Die Datenbank kann direkt im Code erweitert und bearbeitet werden. Die bisherige Zutatenliste mit 32 Einträgen wurde übernommen.
**Probleme und Fehleranalyse:** Bei der Einbindung der Datenbank gab es Schwierigkeiten mit der automatischen Typableitung, insbesondere bei .map { $0.lowercased() }. Außerdem wurden gelbe Markierungen bei den Standardwerten der Mengen- und Einheitenvorschläge angezeigt. Die Typisierung und Funktionsparameter wurden daraufhin vereinfacht.

**Farbsystem und Overlay-Design**
Überarbeitung der Farbauswahl für Zutaten und Kategorien. Weiß ist der Standardzustand ohne Farbe; erst durch Auswahl einer anderen Farbe wird eine Zutat oder Kategorie eingefärbt.
**Probleme und Fehleranalyse:** Die geöffneten Overlays waren plötzlich seitlich abgeschnitten und klebten am Bildschirmrand. Ursache war unter anderem die zu große Mindestbreite des Farbwählers mit acht Farbpunkten und festen Abständen. Die Farbauswahl wurde verkleinert und flexibler gestaltet, sodass die Overlays wieder innerhalb der verfügbaren Bildschirmbreite liegen.

**Fehlerbehebung und Xcode-Umsetzung**
Mehrere Compilerfehler und Warnungen wurden untersucht und behoben. Dazu gehörten Probleme mit ObservableObject, Self, der Typableitung und der Mengenerkennung. Außerdem wurden die SwiftUI-Vorschau und der iPhone-16-Simulator wiederholt getestet.
**Probleme und Fehleranalyse:**
- SwiftUI Preview: Der Compiler konnte einen längeren Ausdruck in parseAmount() nicht rechtzeitig überprüfen. Die Funktion wurde aufgeteilt.
- Gelbe Code-Markierungen: Standardwerte in Funktionsparametern wurden vereinfacht und teilweise in die Funktionen selbst verlagert.
- Weißer Simulator-Bildschirm: Zunächst wurde ein Fehler beim Laden der Startansicht vermutet. Nach längerer Ladezeit startete die App jedoch erfolgreich. Es handelte sich somit nicht um einen dauerhaft fehlerhaften Startbildschirm.

**Datenspeicherung**
Integration einer lokalen Speicherung für Rezepte, Kategorien und Zutaten. Ergänzung von Datenmigrationen, damit ältere Rezepte und bereits gespeicherte Zutaten weiterhin verwendet werden können.
**Probleme und Fehleranalyse:** Durch die Erweiterung der Zutatenstruktur mussten ältere Einträge mit einfachen Textangaben in die neue Datenstruktur übertragen werden. Die Migration wurde so angelegt, dass vorhandene Rezepte nicht durch die neuen Felder verloren gehen.

**Zusammenfassung Zwischenstand**
Alle Schritte in Zusammenarbeit mit KI geordnet dokumentiert.
