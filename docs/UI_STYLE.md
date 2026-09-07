# Стиль monёy

Общий набор компонентов находится в `FinTrack/Views/Components/MoneyComponents.swift`.
Сторонние UI-библиотеки не используются: навигация, формы, меню и выбор даты остаются нативными SwiftUI.

- `MoneyPalette`: фон, адаптивные цвета доходов и расходов. Пользовательский акцент хранится в существующем `appAccentHex`.
- `MoneyLayout`: отступ страницы 20 pt, радиусы карточек 24 pt, элементов управления 18 pt и иконок 12 pt; ширина содержимого до 760 pt.
- `MoneyCard` / `MoneyCardSurface`: плотная поверхность; мягкая акцентная заливка только для главных показателей. `DashboardCard` и `OnboardingCard` используют ту же основу.
- `appGroupedList()`: общее оформление нативных списков и форм.
- `MoneyEntityRow`, `MoneyTransactionRow`, `MoneyProgressSummary`: строки разделов, операций, бюджетов и целей. Суммы используют моноширинные цифры и могут переноситься.
- `MoneyPrimaryButtonStyle`: основные действия в форме Capsule. `MoneyCreateBar` и `MoneyActionBar` — плавающие Capsule + glass через `safeAreaInset`, чтобы до последней строки можно было доскроллить.
- Стекло (`moneyGlassCapsule`) предназначено для плавающих действий: Capsule + glass на iOS 26+, Material на более ранних, при Reduce Transparency — плотная поверхность.
- При расширении интерфейса используйте эти компоненты, сохраняйте выбранный акцент, семантические цвета, Dynamic Type и Reduce Motion.
