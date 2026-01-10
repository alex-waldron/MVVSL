import SwiftUI

extension EnvironmentValues {
    @Entry var saveService = SaveService()
}


struct CounterView: View {
    @State private var viewState = CounterViewState()
    @Environment(\.saveService) private var saveService

    var body: some View {
        let something = CounterViewLogic(viewState: viewState, service: saveService)
        VStack {
            Stepper("Count: \(viewState.count)", value: $viewState.count)
            Button("Save") { something.saveTapped() }
        }
        .background {
            something.backgroundColor
        }
        .task {
            await something.runNotificationObservationUntilCancelled()
        }
    }
}

@Observable @MainActor final class CounterViewState {
    var count = 0
}

@MainActor struct CounterViewLogic {
    let viewState: CounterViewState
    let service: SaveService

    var backgroundColor: Color  {
        viewState.count.isMultiple(of: 2) ? .green : .red
    }

    func saveTapped() {
        service.save(viewState.count)
    }

    func runNotificationObservationUntilCancelled() async {
        let saveNotifications = NotificationCenter.default.notifications(named: .init("SaveCountNotification"))
        for await _ in saveNotifications {
            service.save(viewState.count)
        }
    }
}

#Preview {
    
}
