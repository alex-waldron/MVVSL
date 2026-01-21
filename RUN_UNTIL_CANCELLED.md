# Run Until Cancelled Pattern

## Overview

**Run Until Cancelled** is a Swift concurrency pattern for processing never-ending async sequences for the lifetime of a defined scope. The pattern leverages Swift's structured concurrency and task cancellation to create operations that:

1. Start when a scope begins or a dependency changes
2. Run continuously, processing items from a never-ending async sequence
3. Automatically clean up when the scope ends or dependencies change
4. Exit gracefully when cancelled, with no explicit cleanup code needed

The pattern gets its name from methods typically named `runUntilCancelled()`, which contain infinite `for await` loops over async sequences.

Some examples of these async sequences are:
- State observations (`Observations { state.value }`)
- Network event streams (WebSocket messages, Server-Sent Events)
- Notification streams (`NotificationCenter.default.notifications(named:)`)
- Timer sequences (`Timer.publish().values`)

**Core Use Case:** Processing continuous streams of events or changes for a defined lifetime scope, without manual cleanup logic.

## Lifecycle Scopes

The lifetime of a `runUntilCancelled` operation is determined by **where you place the `.task(id:)` modifier** and **what you use as the task ID**:

**App Lifetime** - Task at app root with no ID or constant ID:
```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .task {
                    await appLogic.runUntilCancelled()
                }
        }
    }
}
```

**User Session Lifetime** - Task at root with user ID:
```swift
RootView()
    .task(id: user.id) {
        // Runs for lifetime of user session
        // Cancels and restarts when user.id changes (login/logout)
        await userScopedLogic.runUntilCancelled()
    }
```

**View Lifetime** - Task on specific view:
```swift
struct FeatureView: View {
    var body: some View {
        content
            .task {
                // Runs while this view is on screen
                await viewLogic.runUntilCancelled()
            }
    }
}
```

**Feature Lifetime** - Task with feature-specific ID:
```swift
.task(id: state.taskID) {
    // Runs until state.taskID changes (manual reload trigger)
    await logic.runUntilCancelled()
}
```

## Key Characteristics

- **Scope-bound**: Runs for the lifetime of its containing scope (app, user, view, feature)
- **Sequence-driven**: Uses `for await` loops over never-ending async sequences
- **Cancellation-aware**: Exits gracefully when task is cancelled
- **Progressive initialization**: Can defer setup until actually needed
- **Zero cleanup code**: Swift structured concurrency handles cleanup automatically

## Basic Structure

The core pattern is a `for await` loop that processes items from a never-ending async sequence:

```swift
func runUntilCancelled() async {
    // Optional: Perform one-time setup
    await setup()

    // Process items from async sequence until cancelled
    for await item in neverEndingSequence {
        await process(item)
    }
}
```

**Example: State Synchronization**
```swift
func runUntilCancelled() async {
    // Load initial data
    state.items = try await store.fetchAll()

    // Observe state changes and persist them
    let snapshots = Observations { state.items }
    for await snapshot in snapshots {
        try await store.persist(snapshot)
    }
}
```

**Example: WebSocket Event Stream**
```swift
func runUntilCancelled() async {
    let connection = await webSocket.connect()

    for await message in connection.messages {
        await handle(message)
    }
}
```

**Example: Notification Stream**
```swift
func runUntilCancelled() async {
    let notifications = NotificationCenter.default
        .notifications(named: .userDidPerformAction)

    for await notification in notifications {
        await process(notification)
    }
}
```

## Integration with SwiftUI

Called from `.task(id:)` modifier:

```swift
struct MyView: View {
    @State private var state = MyState()
    @Environment(\.store) private var store

    var body: some View {
        content
            .task(id: state.taskID) {
                let logic = MyLogic(state: state, store: store)
                await logic.runUntilCancelled()
            }
    }
}
```

The task automatically cancels and restarts when:
- The view disappears (view removed from hierarchy)
- `state.taskID` changes (manual reload trigger)

## When to Use

**Use `runUntilCancelled` for:**
- Processing never-ending async sequences (WebSockets, notifications, timers, state observations)
- Operations that should run for a defined scope lifetime (app, user session, view)
- Event streams that need continuous monitoring
- Long-running reactive operations

**Don't use `runUntilCancelled` for:**
- One-off async operations (use simple `async` methods)
- Operations that naturally complete (single network requests, one-time computations)
- Fire-and-forget operations
- Tasks that need precise manual lifecycle control

## Relationship to MVSL

While often used together, `runUntilCancelled` and MVSL (Model-View-State-Logic) are independent patterns:

- **MVSL** is an architectural pattern for organizing view logic and state
- **runUntilCancelled** is a concurrency pattern for processing never-ending async sequences

You can use `runUntilCancelled` without MVSL, and you can use MVSL without `runUntilCancelled`. They commonly appear together because:
- MVSL Logic types often manage long-running operations
- Logic methods provide a natural place to implement `runUntilCancelled`
- Both patterns work well with SwiftUI's `.task` modifier for lifecycle management
