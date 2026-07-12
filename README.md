# 菜搭子 (Caidazi) — Recipe Pairing App

A smart recipe and ingredient knowledge base app. Scan ingredients, discover pairings, and manage your kitchen knowledge.

## Tech Stack

- **Language:** Swift
- **Framework:** SwiftUI + SwiftData
- **Vision:** CoreML + Vision framework for ingredient recognition
- **Platform:** iOS / macOS

## Project Structure

```
App/           — App entry, DI
Features/      — Home, KnowledgeBase, Recipes, Scanner, Profile
Models/        — Data models + seed data
Services/      — Knowledge base, recognition service
```

### Key Features

- **3-tier recognition:** Custom CoreML -> Vision built-in -> Manual fallback
- **Multilingual label mapping:** 60+ English to Chinese ingredient names
- **Extensible knowledge base:** Custom fields, nested categories, free tags
- **SwiftData + CloudKit sync:** Automatic iCloud synchronization
