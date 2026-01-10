# MVSL

## Overview
MVSL is a lightweight SwiftUI design pattern that splits the traditional ViewModel into two parts:
- **ViewState**: Observable state owned by the view.
- **Logic**: Stateless operations that read/write ViewState and call into Model/services.

This keeps SwiftUI state ownership simple while isolating testable logic.

## Roles
- **Model**: Data and services (networking, persistence, domain models).
- **View**: SwiftUI view, owns state and wires dependencies.
- **ViewState**: Observable state for a single view.
- **Logic**: Pure glue between ViewState and Model.

## Rules of Use
- Views own their ViewState via `@State`.
- Logic is a `struct` created in `body` and takes dependencies + ViewState.
- Logic does not store UI state; it mutates ViewState.
- Async work lives in Logic and is invoked via SwiftUI modifiers (typically `task`).
- Testing targets Logic, with ViewState and mocked services.

## Example
```swift
@MainActor @Observable final class CounterViewState {
    var count = 0
}

struct CounterViewLogic {
    let countService: CountService
    let viewState: CounterViewState

    func increment() {
        viewState.count += 1
    }

    func saveTapped() {
        countService.save(viewState.count)
    }

    func loadCount() async {
        if let count = await countService.getCount() {
            viewState.count = count
        }
    }
}

struct CounterView: View {
    @State private var viewState = CounterViewState()
    @Environment(\.countService) private var countService

    var body: some View {
        let logic = CounterViewLogic(countService: countService, viewState: viewState)
        VStack {
            Stepper("Count: \(viewState.count)", value: $viewState.count)
            Button("Increment") { logic.increment() }
            Button("Save") { logic.saveTapped() }
        }
        .task { await logic.loadCount() }
    }
}
```

## Testing
```swift
@Test func savesCurrentCount() {
    let state = CounterViewState()
    let mockService = MockCountService()
    let logic = CounterViewLogic(countService: mockService, viewState: state)

    state.count = 2
    logic.saveTapped()

    #expect(mockService.savedCount == 2)
}
```

## When to Use
- Views that need `@State`, environment dependencies, and testable logic.
- Screens that benefit from minimal scaffolding and direct SwiftUI integration.
