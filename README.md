# monёy

A personal pet-project finance tracker for iPhone. Track income and expenses, stay on top of budgets, and add several transactions at once with voice.

## Features

- accounts, categories, and subcategories
- expenses, income, and transfers between accounts
- voice input that can recognize multiple operations and open a confirmation list
- bank statement import from CSV, PDF, and XLSX
- budgets, savings goals, and recurring payments
- debt tracking and repayments
- app lock with PIN and Face ID
- widget, Control Center, Siri Shortcuts, and deep links
- offline storage with sync to a custom backend
- data export and receipt attachments

## Stack

- Swift and SwiftUI
- SwiftData
- Speech and AVFoundation
- WidgetKit and App Intents
- PDFKit
- REST API with pull/push sync

## Requirements

- iOS 17+
- Xcode 15+
- Apple Developer Team for device builds

## Getting started

1. Clone the repository.
2. Open `FinTrack.xcodeproj`.
3. Select the `FinTrack` scheme.
4. Set your Development Team and a unique Bundle Identifier.
5. Optionally set `API_BASE_URL` in the scheme or Info.plist.
6. Build and run on a device or simulator.

The project is also described in `project.yml` and can be regenerated with [XcodeGen](https://github.com/yonaskolb/XcodeGen).

> The user-facing app name is **monёy**. The internal Xcode target/module name is still `FinTrack` for signing and App Group compatibility.

## Docs

- [API contract](docs/API_CONTRACT.md)
- [Sync architecture](docs/SYNC_READINESS.md)
- [UI guide](docs/UI_STYLE.md)

## Status

This is a personal pet project. The API and data model may change without backwards compatibility.

---

## На русском

Личный pet-проект финансового трекера для iPhone. Учёт доходов и расходов, бюджеты и быстрый ввод нескольких операций голосом.

**Фичи:** счета и категории, голосовой ввод с подтверждением нескольких операций, импорт выписок, бюджеты/цели/повторы, долги, PIN/Face ID, виджеты и deep links, офлайн + синк, экспорт и чеки.

**Запуск:** открыть `FinTrack.xcodeproj`, схема `FinTrack`, указать свою Development Team и Bundle Identifier.
