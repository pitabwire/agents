---
name: github-issue-workflow
description: End-to-end GitHub issue management, feature development workflow with worktrees, PR-based delivery, and deployment. Use when creating issues, breaking down features, developing with PRs, or deploying changes.
version: "1.0"
last_updated: "2026-02-26"
self_updating: true
---

> **SELF-UPDATING SKILL** — This document MUST be kept accurate. Follow the update protocol below.

## Self-Update Protocol

**WHEN to update this file** (using the Edit tool on this SKILL.md):
1. GitHub CLI (`gh`) commands or flags change
2. PR review workflow or merge strategies change
3. CI/CD pipeline conventions change
4. Issue template format or required fields change
5. Worktree workflow patterns evolve

**HOW to update:**
1. Edit this file at `~/.agents/skills/github-issue-workflow/SKILL.md` using the Edit tool
2. Increment the `version` field in the frontmatter (e.g., "1.0" -> "1.1")
3. Update `last_updated` to today's date (YYYY-MM-DD)
4. Update the affected section(s) to match current best practices
5. Do NOT remove the self-update protocol section

**WHEN NOT to update:**
- Repository-specific CI configurations that don't represent universal workflow changes
- One-off workflow deviations for specific projects

---

# GitHub Issue & Feature Development Workflow

## Activation

Apply this workflow when:
- Creating or refining GitHub issues
- Breaking down large features into smaller tasks
- Developing features from issues
- Creating and managing pull requests
- Deploying and validating changes

---

## Core Principles

1. **Extreme Clarity** - Issues must be so clear that confusion is nearly impossible
2. **Small Context** - Each task small enough to hold entirely in working memory
3. **PR-Based Delivery** - All changes via pull requests that close issues
4. **Worktree Isolation** - Each feature in its own git worktree
5. **Resource Conservation** - Never run builds/tests/lints concurrently in bulk
6. **Validation at Every Stage** - Local → CI → Deploy → Verify

---

## Phase 1: Issue Creation & Refinement

### Issue Quality Checklist

Before an issue is ready for development:

- [ ] **Problem Statement** - What problem are we solving? Why does it matter?
- [ ] **Success Criteria** - How do we know when it's done? (Testable conditions)
- [ ] **Scope Boundaries** - What's explicitly IN and OUT of scope?
- [ ] **Technical Context** - Relevant files, APIs, dependencies
- [ ] **Acceptance Tests** - Specific scenarios that must pass
- [ ] **Dependencies** - Other issues/PRs that must complete first
- [ ] **Size Assessment** - Can be completed in 1-2 focused sessions?

### Issue Template

```markdown
## Problem Statement

[Clear description of the problem. Who experiences it? What's the impact?]

## Proposed Solution

[High-level approach. Not implementation details, but the "what" not "how"]

## Success Criteria

- [ ] [Specific, testable condition 1]
- [ ] [Specific, testable condition 2]
- [ ] [Specific, testable condition 3]

## Scope

### In Scope
- [Explicitly included item 1]
- [Explicitly included item 2]

### Out of Scope
- [Explicitly excluded item 1 - may be separate issue]
- [Explicitly excluded item 2]

## Technical Context

**Relevant Files:**
- `path/to/file1.dart` - [why relevant]
- `path/to/file2.dart` - [why relevant]

**Related APIs/Services:**
- [API or service name] - [how it's involved]

**Dependencies:**
- #123 - [must complete first because...]

## Acceptance Tests

1. **Given** [precondition], **When** [action], **Then** [expected result]
2. **Given** [precondition], **When** [action], **Then** [expected result]

## UI/UX Requirements (if applicable)

**Screens/Components:**
- [ ] [Screen or component 1]
- [ ] [Screen or component 2]

**Design References:**
- [Link to Figma/mockup/screenshot]

**Responsive Requirements:**
- Mobile: [requirements]
- Tablet: [requirements]
- Desktop: [requirements]

**Accessibility:**
- [Any specific a11y requirements]

> Note: Use `frontend-design` skill when implementing UI components

## Notes

[Any additional context, links to designs, discussions, etc.]
```

### Breaking Down Large Issues

**When to Break Down:**
- Estimated effort > 4 hours
- Multiple independent deliverables
- Different areas of the codebase
- Can be parallelized by different people
- Risk of merge conflicts if done together

**Breakdown Strategy:**

```markdown
## Epic: [Large Feature Name]

### Overview
[Brief description of the full feature]

### Sub-Issues

1. **#101 - [Component A]** 
   - [Clear deliverable]
   - Blocks: none
   - Blocked by: none

2. **#102 - [Component B]**
   - [Clear deliverable]  
   - Blocks: #104
   - Blocked by: #101

3. **#103 - [Component C]**
   - [Clear deliverable]
   - Blocks: #104
   - Blocked by: none (can parallel with #101, #102)

4. **#104 - [Integration]**
   - [Combines components, final validation]
   - Blocks: none
   - Blocked by: #101, #102, #103

### Dependency Graph

```
#101 ──┐
       ├──► #104
#102 ──┤
       │
#103 ──┘
```

### Completion Criteria
- All sub-issues closed
- Integration issue validated
- Feature flag enabled (if applicable)
```

### Size Guidelines

| Size | Time Estimate | Characteristics |
|------|---------------|-----------------|
| XS | < 30 min | Single file, obvious change, no tests needed |
| S | 30 min - 2 hrs | Few files, clear scope, straightforward tests |
| M | 2 - 4 hrs | Multiple files, some complexity, test coverage |
| L | 4 - 8 hrs | **Should be broken down** |
| XL | > 8 hrs | **Must be broken down into epic** |

---

## Phase 2: Pre-Development Research

Before writing any code, gather complete context.

### Research Checklist

```markdown
## Pre-Development Research for #[issue-number]

### 1. Codebase Understanding
- [ ] Read all files mentioned in issue
- [ ] Understand existing patterns in this area
- [ ] Identify similar implementations to reference
- [ ] Note any deprecated patterns to avoid

### 2. API/Service Research
- [ ] Review API documentation (use Context7 or official docs)
- [ ] Understand authentication requirements
- [ ] Note rate limits or constraints
- [ ] Test API manually if possible

### 3. Architecture Alignment
- [ ] Confirm approach aligns with existing architecture
- [ ] Identify reusable components
- [ ] Plan for offline-first if applicable
- [ ] Consider error handling strategy

### 4. UI/UX Requirements (if applicable)
- [ ] Identify all screens/components to build
- [ ] Review existing design system usage
- [ ] Note responsive/accessibility requirements
- [ ] **Plan to use `frontend-design` skill for implementation**

### 5. Test Strategy
- [ ] Identify what tests are needed (unit, widget, integration)
- [ ] Note existing test patterns to follow
- [ ] Plan test data requirements

### 6. Unknowns Resolved
- [ ] All questions answered (via issue comments if needed)
- [ ] No ambiguous requirements remain
- [ ] Edge cases identified and documented
```

### When to Ask for Clarification

Ask before coding if:
- Success criteria are ambiguous
- Multiple valid interpretations exist
- Technical approach has trade-offs needing stakeholder input
- Scope boundaries are unclear
- Dependencies on other work are uncertain

**How to ask:**
```markdown
@[maintainer] Before I start on this, I want to clarify:

1. **[Specific question 1]**
   - Option A: [description]
   - Option B: [description]
   - My recommendation: [which and why]

2. **[Specific question 2]**
   - [context for why this matters]

Once clarified, I'll proceed with implementation.
```

---

## Phase 3: Development with Worktrees

### Worktree Setup

```bash
# From main repository
cd /path/to/repo

# Create worktree for the feature
git worktree add ../repo-issue-123 -b feature/123-short-description

# Navigate to worktree
cd ../repo-issue-123

# Verify clean state
git status
```

### Worktree Naming Convention

```
{repo-name}-issue-{number}
{repo-name}-{branch-type}-{description}

Examples:
- chat-issue-456
- api-feature-user-auth
- webapp-fix-login-redirect
```

### Branch Naming Convention

```
{type}/{issue-number}-{short-description}

Types:
- feature/ - New functionality
- fix/     - Bug fixes
- refactor/ - Code improvements (no behavior change)
- docs/    - Documentation only
- chore/   - Maintenance (deps, configs)

Examples:
- feature/123-add-dark-mode
- fix/456-prevent-double-submit
- refactor/789-extract-auth-service
```

### Development Flow in Worktree

```bash
# 1. Ensure up-to-date with main
git fetch origin
git rebase origin/main

# 2. Make changes in small, logical commits
git add -p  # Stage interactively
git commit -m "feat(auth): add token refresh logic

- Implement TokenRefreshCoordinator
- Add mutex to prevent concurrent refreshes
- Handle transient vs permanent errors

Refs #123"

# 3. Continue development...

# 4. Before creating PR, ensure everything works
# (See Phase 4 for validation steps)
```

### Commit Message Format

```
{type}({scope}): {short description}

{body - what and why, not how}

{footer - references, breaking changes}
```

**Types:** feat, fix, refactor, docs, test, chore, perf, style

**Examples:**
```
feat(tasks): add offline task creation

Tasks can now be created while offline and will sync
when connectivity is restored. Uses the SyncQueue
pattern established in the chat feature.

Closes #123

---

fix(auth): prevent logout on transient network errors

Previously, any token refresh failure would log out the user.
Now we classify errors as transient (retry) vs permanent
(logout required), improving UX on flaky connections.

Fixes #456

---

refactor(database): extract DAO base class

No functional changes. Reduces duplication across DAOs
by extracting common CRUD operations to BaseDao.

Refs #789
```

---

## Phase 4: Local Validation (Sequential)

**CRITICAL: Never run builds, tests, and lints concurrently in bulk.**

Run validations sequentially to conserve resources:

### Validation Order

```bash
# 1. Static Analysis (fast, catches obvious issues)
flutter analyze
# or
dart analyze

# Wait for completion before proceeding

# 2. Format Check (fast)
dart format --set-exit-if-changed .

# Wait for completion before proceeding

# 3. Build (ensure it compiles)
flutter build apk --debug
# or for web
flutter build web

# Wait for completion before proceeding

# 4. Unit Tests (targeted)
flutter test test/unit/

# Wait for completion before proceeding

# 5. Widget Tests (if applicable)
flutter test test/widget/

# Wait for completion before proceeding

# 6. Integration Tests (if applicable, slowest)
flutter test integration_test/
```

### Resource-Conscious Testing

```bash
# Run tests for specific feature only
flutter test test/features/auth/

# Run single test file
flutter test test/features/auth/token_refresh_test.dart

# Run with reduced concurrency if needed
flutter test --concurrency=1

# Skip slow tests during development iteration
flutter test --exclude-tags=slow
```

### Pre-PR Checklist

```markdown
## Local Validation for #[issue-number]

### Static Analysis
- [ ] `flutter analyze` - No errors or warnings
- [ ] `dart format --set-exit-if-changed .` - All files formatted

### Build
- [ ] Debug build succeeds
- [ ] No new deprecation warnings introduced
- [ ] No increase in build warnings

### Tests
- [ ] All existing tests pass
- [ ] New tests added for new functionality
- [ ] Test coverage maintained or improved

### Manual Testing
- [ ] Feature works as specified in acceptance tests
- [ ] Edge cases verified
- [ ] Error states handled gracefully
- [ ] Offline behavior correct (if applicable)

### Code Quality
- [ ] No deprecated APIs used
- [ ] Follows existing code patterns
- [ ] No unnecessary changes to unrelated files
- [ ] Commit history is clean and logical
```

---

## Phase 5: Pull Request Creation

### PR Template

```markdown
## Summary

[Brief description of what this PR does]

Closes #[issue-number]

## Changes

- [Change 1]
- [Change 2]
- [Change 3]

## Testing

### Automated
- [ ] All existing tests pass
- [ ] Added tests for [new functionality]

### Manual Testing Steps
1. [Step 1]
2. [Step 2]
3. [Verify expected result]

## Screenshots/Recordings

[If UI changes, include before/after]

## Checklist

- [ ] Code follows project style guidelines
- [ ] Self-reviewed the diff
- [ ] No console.log/print statements left
- [ ] Documentation updated if needed
- [ ] No unrelated changes included
```

### PR Best Practices

1. **One Issue, One PR** - Each PR closes exactly one issue
2. **Small PRs** - Easier to review, faster to merge
3. **Draft First** - Create as draft if still iterating
4. **Link Issue** - Use "Closes #X" or "Fixes #X" in description
5. **Request Review** - Tag appropriate reviewers
6. **Respond Promptly** - Address review feedback quickly

### Creating the PR

```bash
# Push branch to remote
git push -u origin feature/123-short-description

# Create PR via CLI
gh pr create \
  --title "feat(auth): add token refresh logic" \
  --body-file .github/pr-body.md \
  --assignee @me \
  --label "feature"

# Or create as draft
gh pr create --draft ...
```

---

## Phase 6: CI Validation

### Monitoring CI

```bash
# Check PR status
gh pr checks

# View specific check logs
gh run view [run-id] --log

# Wait for all checks
gh pr checks --watch
```

### CI Failure Response

| Failure Type | Response |
|--------------|----------|
| Lint/Format | Fix locally, push |
| Build | Fix locally, push |
| Unit Tests | Fix locally, verify, push |
| Integration Tests | Investigate flakiness vs real failure |
| Coverage | Add tests if genuinely missing coverage |

```bash
# After fixing CI issues
git add .
git commit -m "fix: address CI feedback

- Fix linting errors in auth_service.dart
- Add missing test for edge case"

git push
```

---

## Phase 7: Code Review

### As Author

1. **Self-Review First** - Review your own diff before requesting
2. **Explain Context** - Add comments explaining non-obvious decisions
3. **Be Responsive** - Address feedback within 24 hours
4. **Don't Take It Personally** - Reviews improve code quality

### Responding to Feedback

```markdown
# Agree and will fix
> Reviewer: This should use `withOpacity` not `withValues`
✅ Good catch, fixed in abc123

# Disagree with explanation
> Reviewer: Should we add caching here?
🤔 I considered caching but decided against it because:
1. The data changes frequently
2. Cache invalidation would be complex
3. Current latency is acceptable (<100ms)

Happy to add if you still think it's valuable.

# Need clarification
> Reviewer: This pattern seems unusual
❓ Could you elaborate on what concerns you? I based this on 
the pattern in `other_service.dart:145` but open to alternatives.
```

### Review Feedback Resolution

**CRITICAL: All review feedback must be exhaustively addressed before merge.**

Unresolved feedback leads to technical debt, bugs, and erosion of code quality standards.

#### Feedback Resolution Checklist

```markdown
## Review Feedback Resolution for PR #[number]

### Feedback Items

| # | Reviewer | Feedback | Status | Resolution |
|---|----------|----------|--------|------------|
| 1 | @reviewer | [summary] | ✅ Resolved | [how addressed] |
| 2 | @reviewer | [summary] | ✅ Resolved | [how addressed] |
| 3 | @reviewer | [summary] | 💬 Discussed | [outcome agreed] |

### Resolution Status
- [ ] All feedback items catalogued
- [ ] Each item either fixed OR explicitly discussed and agreed
- [ ] No unresolved threads remain
- [ ] Reviewer has approved final state
```

#### Feedback Resolution States

| State | Meaning | Action Required |
|-------|---------|-----------------|
| ✅ Resolved | Fixed as requested | Commit pushed, reply confirming |
| 💬 Discussed | Disagreed, discussed, agreed on outcome | Document agreement in thread |
| 🔄 Deferred | Agreed to address in follow-up issue | Create issue, link in thread |
| ❌ Unresolved | Not yet addressed | **BLOCKS MERGE** |

#### How to Address Each Feedback Type

```markdown
# Feedback: Code change requested
1. Make the requested change
2. Commit with message referencing feedback
3. Reply: "Fixed in [commit-sha]. @reviewer please confirm this addresses your concern."
4. **WAIT for reviewer confirmation before resolving thread**
5. Request re-review if substantial changes

# Feedback: Question or clarification needed
1. Provide clear, complete answer
2. Add code comments if it helps future readers
3. Reply with explanation
4. Tag reviewer: "@reviewer does this clarify?"
5. **WAIT for reviewer confirmation before resolving thread**

# Feedback: Disagree with suggestion
1. Reply with clear reasoning
2. Provide technical justification
3. Offer alternatives if applicable
4. Tag reviewer: "@reviewer what do you think about this approach?"
5. **WAIT for reviewer response**
6. If impasse, escalate to team lead
7. Document final decision in thread
8. Only resolve after explicit agreement

# Feedback: Out of scope for this PR
1. Acknowledge the point is valid
2. Create follow-up issue
3. Reply: "Good point. Created #[issue] to address this separately. @reviewer is deferring OK?"
4. **WAIT for reviewer agreement to defer before resolving**
```

#### Reviewer Confirmation Required

**NEVER resolve a thread yourself.** Always:

1. Tag the reviewer explicitly: `@reviewer`
2. Ask for confirmation: "Does this address your concern?"
3. Wait for their response
4. Let the reviewer resolve the thread, OR
5. Resolve only after they explicitly confirm (e.g., "Looks good", "Approved", "LGTM")

```markdown
# Example flow:

Reviewer: "This should handle the null case"

You: "Fixed in abc123 - added null check with early return. 
      @reviewer please confirm this addresses your concern."

Reviewer: "Looks good, thanks!"

[Now you may resolve the conversation]
```

#### Merge Blockers

**DO NOT MERGE if any of these are true:**

- [ ] Unresolved review threads exist
- [ ] Reviewer has requested changes (not yet approved)
- [ ] Feedback was dismissed without discussion
- [ ] "Will fix later" without tracking issue created
- [ ] Reviewer hasn't explicitly confirmed their concerns are addressed
- [ ] Threads resolved without reviewer confirmation (e.g., "LGTM", "Looks good")
- [ ] Reviewer not tagged on responses to their feedback

#### Resolving Threads Properly

```bash
# Wrong: Resolving without addressing
❌ [Resolve conversation] (without reply or fix)

# Wrong: Dismissing valid feedback
❌ "I think it's fine as-is" [Resolve conversation]

# Wrong: Resolving without reviewer confirmation
❌ "Fixed in abc123" [Resolve conversation immediately]

# Wrong: Not tagging reviewer
❌ "Fixed in abc123" (no @mention, reviewer may not see it)

# Right: Fix, tag, and wait for confirmation
✅ "Fixed in abc123. @reviewer please confirm."
   ... wait ...
   Reviewer: "LGTM"
   [Now resolve conversation]

# Right: Discuss, tag, and wait for agreement
✅ "I see your point, but [reasoning]. @reviewer what do you think?"
   ... wait for response ...
   Reviewer: "Good point, let's go with your approach"
   [Now resolve conversation]

# Right: Defer with tracking and confirmation
✅ "Valid concern. Created #456 to address. @reviewer OK to defer?"
   ... wait ...
   Reviewer: "Yes, approved to defer"
   [Now resolve conversation]
```

### After All Feedback Addressed

```bash
# Verify no unresolved threads
gh pr view --comments | grep -i "unresolved"

# Verify approval status
gh pr checks
gh pr view --json reviews --jq '.reviews[-1].state'
# Should show: "APPROVED"

# Ensure up-to-date with main
git fetch origin
git rebase origin/main

# Force push if rebased
git push --force-with-lease

# Final verification before merge
gh pr view

# Merge only when ALL conditions met:
# - All checks passing
# - All threads resolved
# - Approved by required reviewers
# - Up-to-date with main
gh pr merge --squash --delete-branch

# Or merge via GitHub UI
```

---

## Phase 8: Deployment

### Pre-Deployment Checklist

```markdown
## Deployment Checklist for #[issue-number]

### Pre-Deploy
- [ ] PR merged to main
- [ ] All CI checks passed on main
- [ ] No conflicting deployments in progress
- [ ] Deployment window is appropriate

### Deploy
- [ ] Trigger deployment (manual or automatic)
- [ ] Monitor deployment progress
- [ ] Verify deployment completed successfully

### Post-Deploy Verification
- [ ] Application is accessible
- [ ] Health checks passing
- [ ] Feature works as expected in production
- [ ] No new errors in monitoring
- [ ] Performance metrics normal
```

### Deployment Commands

```bash
# Check deployment status
gh run list --workflow=deploy

# Trigger deployment (if manual)
gh workflow run deploy.yml -f environment=staging

# Monitor deployment
gh run watch [run-id]
```

### Staged Rollout

```
1. Deploy to staging → Verify
2. Deploy to production (canary 5%) → Monitor 15 min
3. Expand to 25% → Monitor 30 min
4. Expand to 100% → Monitor 1 hour
5. Close issue as completed
```

---

## Phase 9: Post-Deployment Validation

### Verification Checklist

```markdown
## Post-Deployment Verification for #[issue-number]

### Functional Verification
- [ ] Feature accessible in production
- [ ] All acceptance tests pass manually
- [ ] Edge cases work correctly
- [ ] Error handling works as expected

### Performance
- [ ] Response times within acceptable range
- [ ] No memory leaks observed
- [ ] CPU usage normal

### Monitoring
- [ ] No new errors in logs
- [ ] No increase in error rate
- [ ] No alerts triggered

### User Impact
- [ ] Feature visible to intended users
- [ ] Feature flag state correct (if applicable)
- [ ] Analytics events firing correctly
```

### If Issues Found

```bash
# If critical issue, rollback immediately
gh workflow run rollback.yml -f version=previous

# Create hotfix issue
gh issue create \
  --title "fix: [brief description of production issue]" \
  --body "Discovered after deploying #123. [details]" \
  --label "hotfix,priority:high"
```

---

## Phase 10: Issue Closure

### Closing the Issue

```bash
# Verify PR closed the issue automatically
gh issue view 123

# If not auto-closed, close manually with comment
gh issue close 123 --comment "Completed in #456, verified in production."
```

### Post-Mortem (if issues occurred)

```markdown
## Post-Mortem: Issue #123

### What Happened
[Brief description of what went wrong]

### Timeline
- HH:MM - Deployed
- HH:MM - Issue detected
- HH:MM - Rolled back / Fixed
- HH:MM - Verified resolved

### Root Cause
[Why did this happen?]

### What We Learned
- [Learning 1]
- [Learning 2]

### Action Items
- [ ] [Preventive measure 1] - Owner: @person
- [ ] [Preventive measure 2] - Owner: @person
```

---

## Worktree Cleanup

After issue is closed and verified:

```bash
# Return to main repo
cd /path/to/repo

# Remove worktree
git worktree remove ../repo-issue-123

# Or force remove if issues
git worktree remove --force ../repo-issue-123

# Prune any stale worktrees
git worktree prune

# Delete local branch (remote should be deleted by PR merge)
git branch -d feature/123-short-description
```

---

## Quick Reference

### Commands Cheatsheet

```bash
# Issue Management
gh issue create                    # Create new issue
gh issue list                      # List open issues
gh issue view 123                  # View issue details
gh issue close 123                 # Close issue

# Worktree Management
git worktree add ../dir -b branch  # Create worktree
git worktree list                  # List worktrees
git worktree remove ../dir         # Remove worktree
git worktree prune                 # Clean stale entries

# PR Management
gh pr create                       # Create PR
gh pr list                         # List PRs
gh pr checks                       # View CI status
gh pr merge --squash              # Merge PR
gh pr close                        # Close without merge

# CI/Deployment
gh run list                        # List workflow runs
gh run view [id]                   # View run details
gh run watch [id]                  # Watch run progress
```

### Workflow State Machine

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐  │
│  │  Issue   │───►│ Research │───►│  Develop │───►│    PR    │  │
│  │ Created  │    │  Phase   │    │(Worktree)│    │ Created  │  │
│  └──────────┘    └──────────┘    └──────────┘    └──────────┘  │
│       │               │               │               │         │
│       │               │               │               ▼         │
│       │               │               │         ┌──────────┐   │
│       │               │               │         │    CI    │   │
│       │               │               │         │  Checks  │   │
│       │               │               │         └──────────┘   │
│       │               │               │               │         │
│       ▼               ▼               ▼               ▼         │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    Needs Clarification?                  │   │
│  │                         ▼                                │   │
│  │              Ask → Wait → Resume                         │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│       ┌──────────┐    ┌──────────┐    ┌──────────┐             │
│       │  Review  │◄───│ CI Pass  │    │ CI Fail  │──► Fix      │
│       │          │    └──────────┘    └──────────┘     │       │
│       └──────────┘                                     │       │
│            │                                           │       │
│            ▼                                           ▼       │
│       ┌──────────┐    ┌──────────┐    ┌──────────┐             │
│       │  Merge   │───►│  Deploy  │───►│  Verify  │             │
│       └──────────┘    └──────────┘    └──────────┘             │
│                                             │                   │
│                                             ▼                   │
│                                       ┌──────────┐             │
│                                       │  Close   │             │
│                                       │  Issue   │             │
│                                       └──────────┘             │
│                                             │                   │
│                                             ▼                   │
│                                       ┌──────────┐             │
│                                       │ Cleanup  │             │
│                                       │ Worktree │             │
│                                       └──────────┘             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Anti-Patterns

| Don't | Do Instead |
|-------|------------|
| Start coding with unclear requirements | Research and clarify first |
| Create large, multi-week issues | Break down into <4hr tasks |
| Develop directly on main branch | Use worktrees with feature branches |
| Run all tests/builds in parallel | Run sequentially to conserve resources |
| Create PR without local validation | Validate locally before pushing |
| Merge without CI passing | Wait for all checks to pass |
| Merge with unresolved review threads | Address ALL feedback exhaustively |
| Resolve threads without addressing | Fix, discuss, or defer with tracking issue |
| Resolve threads without reviewer confirmation | Tag reviewer, wait for explicit "LGTM" |
| Respond without tagging reviewer | Always @mention the reviewer |
| Dismiss reviewer concerns | Discuss until agreement or escalate |
| "Will fix later" without tracking | Create follow-up issue and link it |
| Deploy without verification plan | Have explicit post-deploy checklist |
| Leave worktrees after completion | Clean up worktrees after merge |
| Close issues without production verification | Verify in production before closing |
| Skip post-mortem after incidents | Document learnings and action items |

---

## Integration with Other Skills

| Phase | Skill to Use |
|-------|--------------|
| Flutter feature development | `flutter-patterns` |
| Riverpod state management | `flutter-riverpod-state-management` |
| **UI/UX design and implementation** | **`frontend-design`** |
| Go backend development | `golang-patterns` |
| API documentation research | Context7 MCP |
| Code review | `code-review` skill |
| Architecture planning | `software-architecture` skill |

### Frontend Design Integration

**Always invoke `frontend-design` skill when:**
- Creating new screens or pages
- Building UI components (buttons, cards, dialogs, forms)
- Implementing visual designs or mockups
- Adding animations or transitions
- Styling existing components
- Building responsive layouts
- Creating landing pages or marketing content

The `frontend-design` skill ensures:
- High design quality avoiding generic AI aesthetics
- Creative, polished, production-grade interfaces
- Proper use of design systems (Material 3, etc.)
- Responsive and accessible implementations
- Consistent visual language across the application

---

## Related Topics

git-worktrees | pull-requests | continuous-integration | deployment | issue-tracking
