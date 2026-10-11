# Solutions

## 1. Tickets and Features

### RES-101 — Search shows results for the wrong query

**Root cause:** Search requests could complete out of order. A slower response for an earlier, shorter query could overwrite the results for the latest query.

**Fix:** I added a debounce before sending requests and a request-identity check so only the latest request can update the results. Debouncing reduces unnecessary API calls, while request identity protects against out-of-order responses when network latency varies.

**Alternative considered:** Debouncing alone does not prevent an older request from completing last, so I kept both protections.

**Edge cases considered:** Older responses arriving late, the query changing while a request is in flight, and the user clearing the search field.

### RES-102 — Crash after leaving My Orders

**Root cause:** A periodic pickup countdown timer continued calling `setState()` after its widget had been disposed, causing a lifecycle-related exception.

**Fix:** I stored the `Timer.periodic()` instance in a nullable `Timer` field named `_timer`. In the widget's `dispose()` method, I cancel the timer before calling `super.dispose()`. This ensures the periodic callback stops when the widget is removed.

**Alternative considered:** Checking `mounted` before calling `setState()` could prevent the immediate exception, but the timer would continue running. Cancelling it directly addresses the resource-lifecycle issue.

**Edge cases considered:** Navigating away before the next timer tick, disposing the widget while the timer is active, and reopening the screen with a new timer.

### RES-103 — Requests pile up after browsing deal pages

**Root cause:** A GetX worker registered with `ever()` continued listening to cart item-count changes without being explicitly disposed when its controller closed.

**Fix:** I stored the `Worker` returned by `ever(cartService.itemCount, ...)` in `_cartItemCountWorker`. In the controller's `onClose()` method, I dispose of the worker before calling `super.onClose()`. This removes the listener when the controller is no longer needed.

**Alternative considered:** Adding guards inside the callback would not unregister the listener. Explicitly disposing of the worker is the appropriate lifecycle cleanup.

**Edge cases considered:** Opening and closing multiple deal pages and changing the cart item count after a controller has been closed.

### RES-104 — Duplicate deals in the home feed

**Root cause:** Pagination and pull-to-refresh could overlap. A pagination request started for the previous feed could complete after a refresh and append stale results. Repeated pagination requests could also interfere with page tracking.

**Fix:** I added `_isRefreshing`, `_isFetchingMore`, and `_requestGeneration` to coordinate refresh and pagination.

- **Refresh coordination:** `_isRefreshing` prevents overlapping refresh operations and prevents pagination from starting while a refresh is active.
- **Request generation:** Each refresh increments `_requestGeneration`. Requests capture the current generation and only update the feed if their generation is still current.
- **Pagination tracking:** `loadMore()` calculates `nextPage` without immediately changing `_page`. It updates `_page` only after the response is accepted, preventing failed or stale requests from incorrectly advancing pagination.
- **Cleanup:** Both refresh and pagination use `finally` blocks to reset their loading flags and complete the corresponding refresh-controller operation.

**Alternative considered:** Disabling refresh while pagination is running would reduce overlap, but it would make the interaction less responsive. Generation checks provide an additional safeguard against stale responses.

**Edge cases considered:** Refreshing while pagination is in flight, stale responses arriving after a refresh, repeated scroll events, pagination failures, and attempting to load more while refreshing.

### RES-106 — Wrong pickup times and missing "Pickup today" deals

**Root cause:** UTC timestamps were displayed without the appropriate local-time conversion. The "today" comparison checked only the day number instead of comparing the full calendar date. The `isOpen` boundary comparisons also needed consistent handling of equality.

**Fix:** I converted timestamps to local time, compared year, month, and day for the "today" filter, and corrected the start/end boundary handling in `isOpen`.

**Alternative considered:** Changing the backend timestamps would not respect the API contract, which specifies UTC instants. The client should convert timestamps for local display and filtering.

**Edge cases considered:** UTC/local date changes, month and year boundaries, and the current time equalling a pickup-window boundary.

### RES-107 — Deep link opens to a crash

**Root cause:** The deal details route expected a `DealModel`, while a deep link could supply only a deal ID. Treating the ID as a model caused an argument-type or null-related error.

**Fix:** I handled both argument shapes. When navigation supplies a `DealModel`, the existing path is used. When it supplies a deal ID, the app fetches the deal and displays a loading state while the request is in progress.

**Alternative considered:** Showing a fallback error screen would avoid the crash but would not satisfy the requirement for a working deal details page opened from a deep link.

**Edge cases considered:** Navigation from the feed with a model, deep links with an ID, and loading during the fetch. Invalid IDs and fetch failures should also be verified before submission.

### F-1 — Live flash-sale countdowns

**Implementation:** I developed a reusable countdown widget, initially named `FlashDealsCountdown`, and later renamed it to `TimerCountdown` so the component could be reused for other timed UI elements.

I integrated the countdown into the flash-deal section, deal details, and deal cards. I also used it in the cart to display reservation expiry in real time, replacing a static remaining-time display that did not update continuously.

I scoped countdown updates to the timer UI instead of rebuilding unrelated card content every second. I also added cart-service logic to detect expired deals, remove them from the bag, and show a notice.

**Alternative considered:** Rebuilding every complete card every second would be simpler, but could create unnecessary work with many visible countdowns. A reusable countdown widget keeps timer-related updates more localized.

**Edge cases considered:** The countdown reaching zero, expired deals already in the bag, multiple visible countdowns, real-time reservation expiry updates, and avoiding reactive-state mutation during widget build.

**Verification note:** I checked the countdown in the flash-deal section, deal details, deal cards, and cart reservation display. I have not recorded DevTools before/after measurements, so I am not claiming a measured performance improvement.

### F-2 — Impression tracking

**Implementation:** I developed `DealImpressionTracker` to track whether a card is at least 50% visible continuously for one second. I integrated it into the flash-deal section and deal cards, and changed the home-screen mapping to use `asMap()` to obtain each item's position.

I integrated `FakeApiService` with `AnalyticsService` for batched event delivery, automatic retry, and re-queueing after failures. Batches flush at 10 events or 15 seconds after the first unsent event, whichever comes first.

**Alternative considered:** Sending an event immediately when a card appears would create more requests and count brief appearances that do not meet the one-second requirement.

**Edge cases considered:** Visibility dropping below 50% before one second, seeing the same deal on multiple screens, failed batch requests, and the batch reaching 10 events before the timeout.

**Verification note:** Before submission, I would verify the required `home_feed`, `flash_rail`, and `search` sources, once-per-deal-per-session behavior, and delivery on the Analytics debug screen. I have not recorded screenshots or quantitative performance measurements here.

### F-3 — Stock reservations with optimistic UI

**Implementation:** I integrated `reserve` and `releaseReservation` into `CartService`. Adding an item updates the UI optimistically while the reservation request is in progress. If reservation fails, the item is rolled back and a non-technical message is shown.

Cart lines display reservation time remaining through the reusable `TimerCountdown` widget. Quantity changes request a reservation for the new quantity, removing a line releases its reservation, and checkout includes reservation IDs.

I also checked the `410` expired-reservation error and added expiry handling to remove expired items and notify the user.

**Expiry decision:** An expired reservation should not remain presented as secured stock. While the app is open, the cart checks expiry, removes expired items, attempts to release holds where possible, and shows a notice. A checkout `410` should invalidate the affected reservation/cart state and explain that the user needs to reserve the item again. A transient `502` should not automatically clear the cart because the reservation may still be valid and checkout may be retried.

**Alternative considered:** Leaving expired items in the cart until checkout would defer the failure and mislead the user. Automatically retrying checkout after `410` would be unsafe because the reservation must be renewed first.

**Edge cases considered:** `409` stock contention, expiry while the cart is open, expiry during checkout, quantity-update failure requiring rollback, and reservation-release failure. Quantity adjustment uses separate reserve/release requests rather than an atomic server-side resize, which is a limitation to review against the backend contract.

**Verification note:** I checked reservation API behavior, expiry handling, quantity limits, and user feedback.

## 2. AI Usage Log

I mainly used ChatGPT and Gemini during coding sessions to discuss implementation approaches, review code, and reason about edge cases. I reviewed and adapted the suggestions to the existing project structure and API contracts. I remain responsible for the submitted code and should be able to explain the implementation during the follow-up interview.

The assessment requires two concrete examples of AI suggestions that were wrong or misleading. The first example below reflects an issue I encountered during implementation. I should add a second example only if I can identify a genuine instance from my coding sessions.

### Example 1 — Static reservation countdown

- **AI suggestion:** Use a static remaining-time display for the cart reservation.
- **Why it was wrong or misleading:** The reservation expiry needed to update in real time. A static value did not show the remaining reservation time decreasing while the user stayed on the cart screen.
- **How I caught it:** I ran the app on my device, added a deal to the cart, and observed that the reservation time did not count down in real time.
- **What I did instead:** I reused my existing countdown implementation, renamed `FlashDealsCountdown` to `TimerCountdown`, and used the reusable widget to update the reservation countdown continuously.

### Example 2 — Incorrect static error message for reservation failures

- **AI suggestion:** The AI suggested using a static error message when an API reservation request failed instead of displaying the actual API error message.

- **Why it was wrong or misleading:** A static message might not accurately describe the actual error returned by the API. This could confuse users because the displayed message might not match the reason the reservation failed.

- **How I caught it:** When I tested the reservation feature, the API returned a `409` status code with the error message "Not enough stock left." However, the app displayed the static message "Could not reserve: someone grabbed the last one. Try again." This did not accurately reflect the API response.

- **What I did instead:** I updated the error handling to use the message from the API exception instead of a static message, allowing the app to display the actual error returned by the API.

## 3. Design Questions

### Q1. GetX controller lifecycle vs. widget `State` lifecycle

A `GetxController` manages screen or application logic and state through lifecycle methods such as `onInit()` and `onClose()`. It can expose reactive values with `.obs`. A widget's `State` manages a particular widget instance through methods such as `initState()`, `build()`, and `dispose()`.

Resources should be cleaned up by the lifecycle that owns them. In RES-102, the widget owned a periodic timer that called `setState()`. Storing the timer and cancelling it in `dispose()` prevents the callback from continuing after the widget is disposed.

In RES-103, the controller owned a GetX worker. Storing the worker and disposing of it in `onClose()` prevents the listener from continuing to react after the controller is closed.

### Q2. When can a large `Obx` subtree hurt performance?

If a large subtree is wrapped in one `Obx`, a change to an observed value used by its builder can rebuild the entire subtree. This can perform unnecessary work when only a small part of the UI changes, especially in a feed with many countdowns.

I would place `Obx` close to the widgets that depend on each reactive value while keeping the structure maintainable. Flutter DevTools can help confirm whether the chosen rebuild scope avoids unnecessary work.

### Q3. How would I test RES-106 automatically?

Unfortunately, I am not yet familiar with writing automated tests. For this assessment, I tested my code manually on my device to check whether the functionality worked as expected.

For RES-106, I would test different pickup times, including UTC-to-local time conversion, date changes across months or years, and cases where the current time equals the pickup window's start or end time.

I understand that automated tests would help verify these edge cases consistently and catch regressions in the future. Learning how to write unit tests is an area I would like to improve.

## 4. Time Spent

| Ticket / Feature |            Time spent |
| ---------------- | --------------------: |
| RES-101          |            15 minutes |
| RES-102          |            15 minutes |
| RES-103          |            15 minutes |
| RES-104          |            30 minutes |
| RES-106          |            15 minutes |
| RES-107          |            30 minutes |
| F-1              |     1 hour 30 minutes |
| F-2              |               2 hours |
| F-3              |     1 hour 30 minutes |
| **Total**        | **7 hours 5 minutes** |