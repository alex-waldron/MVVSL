# SwiftUI Architecture

## Conventional MVVM (Model-View-ViewModel) doesn't work with SwiftUI

The core issue in MVVM comes from the responsibility of the `ViewModel`. Though the definition is overloaded and ambiguous, the most common way it's defined is "view state + logic". This makes it a pain to work with `SwiftUI` primitives.

**Given** a view has the following requirements:
- external deps (ex: in the `SwiftUI.Environment`, params passed into the view's init, etc)
- State that the view owns (uses `SwiftUI.State`)
- Testable

MVVM is a PITA. (man I love four letter acronyms)

Take this example of a CounterView. 
We have a count service that we want to dependency inject using SwiftUI's environment

```swift
// Service in Environment
final class CountService {
    private var savedCount: Int?

    func save(_ count: Int) {
        savedCount = count
    }

    func getCount() async -> Int? {
        savedCount
    }

    func getSavedCount() -> Int? {
        savedCount
    }
}

extension EnvironmentValues {
    @Entry var countService = CountService()
}
```

Then we want to use this service in a view model.

```swift
@MainActor @Observable final class CounterViewModel {
    var count = 0
    private let countService: CountService

    init(countService: CountService) { 
        self.countService = countService 
    }

    func saveTapped() { 
        countService.save(count) 
    }
}
```

and then to use it in a view
```swift
import SwiftUI

// can't read environment in init so we need this wrapper view
struct WrapperView: View {
    @Environment(\.countService) private var countService

    var body: some View {
        CounterView(viewModel: CounterViewModel(countService: countService))
    }
}

private struct CounterView: View {
    @Bindable var viewModel: CounterViewModel

    var body: some View {
        VStack {
            Stepper("Count: \(viewModel.count)", value: $viewModel.count)
            Button("Save") { viewModel.saveTapped() }
        }
    }
}
```

1. Nothing owns CounterViewModel (eg: no `State`). If `WrapperView` ever recomputes, the view model gets recreated and the count resets to 0.
2. The need for a wrapper view is annoying

To fix the bug, `CounterViewModel` needs State. 
There are two ways of doing this:

1. Make view model a state prop in WrapperView
```swift
// can't read environment in init so we need this wrapper view
struct WrapperView: View {
    @Environment(\.countService) private var countService

    @State var viewModel: CounterViewModel?

    var body: some View {
        Group {
            if let viewModel {
                CounterView(viewModel: viewModel)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = CounterViewModel(countService: countService)
            }
        }
    }
}
```

Cons: 
- why tf is there an optional that has to be dealt with? It won't ever be optional.
- body must be computed twice. 

2. Have CounterView create and own the ViewModel

Use `State(wrappedValue:)`. Update `CounterView` to take in a CountService
```swift
// can't read environment in init so we need this wrapper view
private struct CounterView: View {
    @State private var viewModel: CounterViewModel

    init(countService: CountService) {
        self._viewModel = State(wrappedValue: CounterViewModel(countService: countService))
    }
    // ...
}
```
Cons:
- Use the `State.init(wrappedValue:)` which is risky at best. Better hope the input never changes
    - In this case the wrappedValue `CountService` won't change but even needing to even think of that is annoying af
- Using an underscore-prefixed api REEKS of a code smell

## New Design Pattern: MVSL
### Tenets
If you don't care about all of the following, this design is not for you

#### Idiomatic SwiftUI
Must work seamlessly with SwiftUI. Take advantage of all the primitives (`State`, `Binding`, `Environment`, `Observable`). Working with the system leads to the smallest maintenance burden possible

#### Little to no abstractions
MVSL is purely a design pattern. It does not impose a "must use" architecture for all screens. It's simply a slight restructuring of a ViewModel which minimizes any sort of learning curve. This tenet is the reason TCA was not chosen. See [Why not TCA](#why-not-tca) for more details.

#### Testable
It must be test platform / test pattern agnostic. The pattern must get logic out of the view

### Core Concepts of MVSL
- **Model**: Data model. Pure Data, Services, etc. Same as MVVM.
- **View**: SwiftUI view. Same as MVVM
- **ViewState**: The state of your view. Typically an `Observable`
- **Logic**: The glue between your `ViewState` and your `Model`. Used in the `body` of a `View`

The only difference between MVVM and MVSL is the decomposition of the `ViewModel` into `ViewState` and `Logic`.

### Example
Continuing with our CounterView example, to adopt MVSL we must decompose the CounterViewModel into two pieces; `ViewState` and `Logic`

```swift
@MainActor @Observable final class CounterViewState {
    var count = 0
}

struct CounterViewLogic {
    let countService: CountService
    let viewState: CounterViewState

    func saveTapped() { countService.save(viewState.count) }
}
```

Then in our `CounterView`
```swift
struct CounterView: View {
    @State private var viewState = CounterViewState()
    @Environment(\.countService) private var countService

    var body: some View {
        let logic = CounterViewLogic(countService: countService, viewState: viewState)
        VStack {
            Stepper("Count: \(viewState.count)", value: $viewState.count)
            Button("Save") { logic.saveTapped() }
        }
    }
}
```

### Testing
The `Logic` portion of MVSL is your testable unit.

```swift
@Test func example() {
    // set up
    let state = CounterViewState()
    let mockService = CountService()
    let logic = CounterViewLogic(countService: mockService, viewState: state)

    // user changes count via stepper
    state.count += 1

    // user presses save
    logic.saveTapped()

    // ensure its saved
    #expect(mockService.getSavedCount() == 1)
}
```

### Async work
Async methods live in `Logic` and are called in SwiftUI's `task` modifier
```swift
extension CounterViewLogic {
    func loadCountFromService() async {
        if let count = await countService.getCount() {
            viewState.count = count
        }
    }
}
```

It also works well for observing

```swift
extension CounterViewLogic {
    func runNotificationObservationUntilCancelled() async {
        let saveNotifications = NotificationCenter.default.notifications(named: .init("SaveCountNotification"))
        for await _ in saveNotifications {
            countService.save(viewState.count)
        }
    }
}
```

## Appendix
### Why not TCA
TCA is sick. The more that I understand it, the more that my brain is tickled. It feels "raw", "correct", and makes me feel smart when I figure out what's going. The problem is it took forever to figure out wtf is going on. With the new design pattern, given that a developer is familiar with SwiftUI, you look at the code and say "Hm, this isn't the typical MVVM that I'm used to but I get what's going on"

## References
### MVVM definitions
- https://medium.com/@thakurneeshu280/understanding-mvvm-architecture-in-swiftui-ddc10f7f92fa

## See Also
- [MVSL](MVSL.md)
