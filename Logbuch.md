# Logbuch

## So, 11.10.26 (40 min)
Definition Briefing, Erstellung von grobem Arbeitsplan, Konzept Ausarbeitung und Recherche von Programmierung für iOS. 

## So, 18.10.26 (120 min)
Skizzierung von Interface/Interaktionen in App: Wie sollte App aufgebaut sein, welche Abfolge ist am effektivsten, welche Schritte/Zwischenschritte ergeben Sinn, was muss man beachtet, was fehlt, etc.

Design Resources Apple: Recherche auf Apple Developer Site. **Probleme und Fragen:** Design angepasst an Apple oder Individuell? Viel Aufwand, Figma Assets von Apple unübersichtlich. Eigenes Design nur für mein Phone, einfacher weil nicht responsive Coding? 

Entwürfe in Figma: vorläufiger Grundaufbau der App ohne Gestaltung, zur Veranschaulichung der Verwendung/Abläufe/UX. Startseite > Unterkategorie > Rezept. **Probleme und Fragen:** Wo und wie werden Rezepte am besten hinzugefügt. Rezeptseite, guter Aufbau? Zurück mit Geste satt Taste? Löschen und Bearbeiten von Rezepten? Aufbau bei Zutaten hinzufügen mit Overlay?

## Fr, 23.10.26(180 min)
Erstellung Liste: Von Zutaten, Einheiten,.. **Probleme und Fragen:** Illustrierte kleine Icons als Zutaten schwierig: wenn neue Zutaten hinzukommen/hinzugefügt werden, fehlt das Symbol dazu.

Recherche und Einführung Xcode: **Probleme und Fragen:** neuste Version funktioniert auf meinem Mac nicht. >:c

Interface Entwurf Figma: Rezepterstellung, wie sind Zutaten aufgelistet, wie kann man diese eingeben, etc. Kategorien hinzufügen und bearbeiten etc. Erstes Prototyping. **Probleme und Fragen:** Hinzugefügte Zutaten markieren? Color-Coding? Bei Eingabe Größenangaben oder nur Einheiten hinzufügen? Oder Eingabe als Karussell? 

## Fr, 30.10.26 (30 min)
Erste Coding Schritte mit KI: Grundaufbau App mithilfe der ersten 3 Screens (Start, Kategorien, Rezept hinzufügen).

Test Funktion: Test ob eigenes Design umsetzbar ist, erste Fehlermeldungen behoben und erste 3 Screens funktionstüchtig gemacht.

## Sa, 31.10.26 (60 min)
Weitere integration von Funktionen/Screens: Zutaten hinzufügen, Overlay von Zutat und Vorschlägen und eigene Angabe wurden hinzugefügt. **Probleme und Fragen:** Code konnte nicht heruntergeladen werden, Vorschau/Simulation funktioniert nicht mehr. Buttons wurden in Raster dargestellt, und verschwanden teils vom Bildschirm. Bei angeklickten Zutaten: nicht erkenntlich welche man ausgewählt hatte. Rückkehr zur Startseite fehlt.

Überarbeitung von Problemen: Linksbündige Anordnung von Zutaten, Buttons automatisch nach Wortlänge, Abstände optimiert, Umbruch statt Raster. Anpassung der Mengenauswahl durch farbige Hervorhebung. Zurückbutton hinzugefügt.

## So, 01.11.26 (120 min)

Rezeptseite und Rezepteübersicht: Neue Screens für Rezepte wurden hinzugefügt. Hinzufügen von Lösch-Button beim Bearbeiten von Rezepten. Fehlerbehebung bei Zutatenauswahl und Mengeneingabe (Trennung von Einheit/Menge und optionaler Eingabe z.B Type 405). Unterteilung der Zutatenbeschreibung.

Fehlerbehebung: Code zwischendurch überarbeitet und Fehler ausgebessert.

Verwaltung und Bearbeitung von Kategorien: Farbcodierung von Kategorien und Funktion zum Bearbeiten hinzugefügt, sowie Funktion zum Rezepte hinzufügen und Auswahl der Rezepte erkenntlich zu machen. Farbauswahl angepasst, Weiß als Farbe hinzugefügt. **Probleme und Fragen:** Durch Zusatz von weiß, wurden die Overlays insgesamt verändert, sodass Schrift am Rand klebt.

Fehlerbehebung Overlay: Normalzustand Farbe als Weiß, Zusatz Auswahl von Farben. Fehlerbehbung im Code.

Zutaten-Datenbank erstellt: Datenbank als extra swift-Datei angelegt, um Zutaten und deren Vorschläge individuell festzulegen.
