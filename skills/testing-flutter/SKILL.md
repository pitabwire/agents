---
name: testing-flutter
description: Flutter-specific testing standards enforcing thorough widget testing, state coverage, form validation, responsive layout verification, and real user flow testing. Use when writing, modifying, reviewing, or running Flutter/Dart tests.
version: "1.0"
last_updated: "2026-03-13"
self_updating: true
---

> **SELF-UPDATING SKILL** — This document must remain aligned with the Flutter testing conventions and patterns used in this codebase.
>
> **Companion skill:** `testing-core` defines the universal testing philosophy. This skill adds Flutter-specific standards. Both skills apply when working with Flutter tests.

## Flutter Testing Philosophy

The goal is not just widget existence but correctness of user-visible behavior.

---

## Required Coverage Areas

Every Flutter test effort must consider:

- widget rendering correctness
- state transitions
- form validation
- loading states
- error states
- empty states
- user interaction flows
- navigation behavior
- responsive/adaptive layouts
- accessibility semantics where feasible
- offline/slow network states where relevant
- localization-sensitive rendering where relevant

---

## Testing Layers

Use the appropriate combination of:

| Layer | When |
|-------|------|
| **Unit tests** | Pure logic, models, utilities, state management logic |
| **Widget tests** | Component rendering, interaction, state transitions |
| **Golden tests** | Visual regression where useful |
| **Integration tests** | Critical end-to-end user flows |

---

## Flutter-Specific Expectations

### 1. Test real user flows

Cover:

- entering text
- tapping buttons
- submitting forms
- handling validation errors
- rendering results
- retry paths
- permission-denied paths

### 2. Validate all UI states

Every meaningful screen/component must have explicit tests for:

- **initial state**
- **loading state**
- **success state**
- **empty state**
- **error state**

### 3. Responsive behavior

Where UI is adaptive, test multiple screen sizes and layouts.

### 4. Thorough form testing

For forms, verify:

- required fields
- invalid formats
- boundary lengths
- field dependencies
- disabled/enabled submit states
- submission side effects

### 5. No superficial widget tests

A test that only checks a label exists is usually insufficient unless presence itself is the behavior under test.

---

## State Management Testing

When using Riverpod or other state management:

- Test provider state transitions independently
- Test that widgets react correctly to state changes
- Test error and loading states from providers
- Test async operations and their lifecycle
- Verify disposal and cleanup behavior

---

## Navigation Testing

For navigation-dependent flows:

- Verify correct routes are pushed/replaced
- Test deep linking where applicable
- Test back navigation behavior
- Verify navigation guards and redirects
- Test navigation state preservation across rebuilds

---

## Accessibility Testing

Where feasible:

- Verify semantic labels on interactive elements
- Test screen reader traversal order
- Verify sufficient contrast ratios in tests if custom themes are used
- Test focus management for keyboard/switch access

---

## Execution

```bash
flutter test
flutter test integration_test
```

Also consider:

- golden test updates only when intentional
- device/screen-size-sensitive checks
- navigation flow coverage for critical paths
- `flutter test --coverage` for coverage reporting

---

## Definition of Done (Flutter Checklist)

In addition to the universal checklist from `testing-core`:

- [ ] key UI states are covered (initial, loading, success, empty, error)
- [ ] user interactions are covered (tap, type, swipe, submit)
- [ ] validation behavior is covered
- [ ] navigation is covered where relevant
- [ ] responsiveness/adaptive behavior is covered where relevant
- [ ] tests are not merely superficial render checks
- [ ] state management transitions are tested
- [ ] form logic is thoroughly tested

---

## Examples of Correct Preference

### Flutter loan application form

Preferred:

- test field validation
- conditional field visibility
- submit enabled/disabled logic
- loading state on submit
- error rendering
- navigation on success
- responsive layout behavior

Discouraged:

- only checking that the screen title appears

### Dashboard screen with data loading

Preferred:

- test loading spinner appears
- test data renders correctly on success
- test empty state when no data
- test error message on failure
- test pull-to-refresh behavior
- test responsive grid layout at different widths

Discouraged:

- only checking that `DashboardScreen` builds without error

---

## Self-Update Protocol

**WHEN to update:**

- Flutter testing conventions or tooling change
- State management patterns evolve
- New widget patterns are introduced

**HOW to update:**

1. Edit this SKILL.md using the Edit tool
2. Increment `version` field
3. Update `last_updated` to current date
4. Modify affected sections
5. Preserve this self-update protocol section

**WHEN NOT to update:**

- One-off project-specific decisions
- Temporary debugging sessions
