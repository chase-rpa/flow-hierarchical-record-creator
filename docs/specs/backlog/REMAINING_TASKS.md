# Remaining Tasks — Hierarchical Record Creator

**Last updated:** February 16, 2026
**Status:** Deployed and tested in scratch org. Ready for manual validation and release polish.

This document outlines all remaining work to bring this project from "tested" to "publicly released." Tasks are grouped by priority.

---

## Completed

### Deploy & Run Tests in a Scratch Org

- [x] Create a scratch org (`hrc-test` alias, `rpa-dev-hub` Dev Hub)
- [x] Deploy: `sf project deploy start --source-dir force-app --target-org hrc-test`
- [x] Run tests: `sf apex run test --class-names HierarchicalRecordCreatorTest --target-org hrc-test --result-format human --code-coverage`
- [x] All 15 test methods pass
- [x] Code coverage: **93%** (exceeds 90%+ target)
- [x] Fixed rollback bug: added explicit `Database.setSavepoint()` / `Database.rollback()` to ensure DML is rolled back regardless of calling context (test, Flow, direct Apex)

### Create `project-scratch-def.json`

- [x] `config/project-scratch-def.json` exists in the repo
- [x] Scratch org creation works cleanly

### Add CHANGELOG.md

- [x] `CHANGELOG.md` created in repo root with v1.0.0 entry

### GitHub Repository Setup

- [x] Git repo initialized with `main` and `dev` branches
- [x] Remote configured at `git@github-redpoint:chase-rpa/flow-hierarchical-record-creator.git`

---

## Priority 1 — Must Complete Before Release

### 1.1 Validate Rollback Behavior (Manual)

Automated tests now confirm rollback via explicit savepoints. Manual verification in a Flow is still recommended:

- [ ] In a scratch org, create a Screen Flow using the action with intentionally bad data at each level
- [ ] Confirm that when Level 2 (child) insert fails, Level 1 (parent) records do NOT persist
- [ ] Confirm that when Level 3 (grandchild) insert fails, Level 1 and Level 2 records do NOT persist
- [ ] Confirm the Flow's Fault connector receives the error message

### 1.2 Validate LWR Digital Experience Compatibility

This is the primary use case. Must be tested end-to-end.

- [ ] Enable Digital Experiences in the scratch org
- [ ] Create an LWR-based Digital Experience Site (e.g., "Build Your Own" LWR template)
- [ ] Create a Screen Flow that uses the "Create Hierarchical Records" action
- [ ] Embed the Screen Flow in the LWR site (via Flow component on a page)
- [ ] Run the flow as a site user (community/experience user profile)
- [ ] Confirm all 3 levels are created with correct lookup wiring
- [ ] Confirm fault handling works in the LWR context
- [ ] **Sharing context note:** The class uses `with sharing`. If the experience user doesn't have Create access on the target objects, the DML will fail. This is expected behavior — document it if it comes up during testing.

### 1.3 Test Coverage Gaps to Address (Optional)

Current coverage is 93%. These would improve confidence but are not blocking:

- [ ] **Grandchild-level DML rollback:** Test 7 (`testRollbackOnGrandchildFailure`) tests the success path. Consider adding a validation rule on Case to force a grandchild-level DML failure and verify full rollback.
- [ ] **Null index value in list:** Add a test where one entry in `childParentIndex` is `null`. The `validateIndexBounds` method checks for null but this isn't explicitly tested.
- [ ] **Large volume test:** Add a test with 200 parents, 1000 children, 2000 grandchildren to verify bulk behavior and governor limit compliance.

---

## Priority 2 — Should Complete Before Release

### 2.1 Review InvocableVariable Annotations

Flow Builder displays the `label` and `description` from `@InvocableVariable` annotations. These need to be verified in-context:

- [ ] Open a Flow in Flow Builder and add the "Create Hierarchical Records" action
- [ ] Verify all input labels and descriptions are clear and readable in the property editor
- [ ] Verify output labels make sense when storing results
- [ ] Adjust wording if anything is confusing to a non-developer admin

### 2.2 Usage Guide Screenshots

The `docs/guides/user-guides/USAGE_GUIDE.md` references Flow Builder steps but has no screenshots.

- [ ] Add screenshots showing:
  - The Action element search result for "Create Hierarchical Records"
  - The input configuration panel with all fields mapped
  - The output configuration panel
  - A Fault connector wired to an error screen
  - A complete example flow canvas (2-level and 3-level)
- [ ] Store screenshots in `docs/images/` directory
- [ ] Update USAGE_GUIDE.md with `![description](images/filename.png)` references

### 2.3 Push to GitHub

- [ ] Push `dev` branch changes (CHANGELOG.md, savepoint fix) to remote
- [ ] Create PR or merge `dev` → `main`
- [ ] Add repo description: "Generic Salesforce Flow invocable action to create parent → child → grandchild records in a single atomic transaction with automatic lookup wiring. Pure Apex — LWR compatible. By Redpoint Ascent."
- [ ] Add topics: `salesforce`, `apex`, `flow`, `invocable-action`, `lwr`, `digital-experience`, `screen-flow`
- [ ] Verify the README renders correctly on GitHub

---

## Priority 3 — Nice to Have / Post-Release

### 3.1 Unmanaged Package Link

- [ ] Create an unmanaged package in a Dev Hub org containing both classes
- [ ] Generate an install URL (similar to UnofficialSF's install links)
- [ ] Add the install link to README.md as an alternative installation method

### 3.2 Sample Flow (Metadata)

- [ ] Build a working example Screen Flow (Account → Contact → Case) and export it as metadata
- [ ] Add to repo under `examples/` directory
- [ ] Document how to deploy and use the sample flow in the Usage Guide

### 3.3 Video Walkthrough

- [ ] Record a short (3-5 min) screen recording showing:
  - How to deploy the classes
  - How to configure the action in Flow Builder
  - How to build the index mapping with a counter variable
  - The flow running successfully in an LWR site
- [ ] Host on YouTube or Loom and link from README

### 3.4 v2 Feature Candidates

These are documented in the PRD's "Open Questions" section. Not for v1 but worth tracking:

- [ ] **`without sharing` toggle** — Add a `runInSystemContext` boolean input that delegates to a `without sharing` inner class. Needs security review.
- [ ] **Upsert support** — Accept an `operation` input (`insert` or `upsert`) and an external ID field name for upsert scenarios.
- [ ] **4th level support** — Extend to a 4th level for deep hierarchies. Adds complexity to the index mapping.
- [ ] **Return full records instead of just IDs** — Some flows need to reference the inserted records (with all field values) downstream, not just IDs.
- [ ] **AppExchange listing** — If adoption warrants it, package as a managed or unlocked package for AppExchange distribution.

---

## File Inventory

```
flow-hierarchical-record-creator/
├── README.md                          ✅ Written
├── LICENSE                            ✅ Written (MIT)
├── CHANGELOG.md                       ✅ Written
├── .gitignore                         ✅ Written
├── sfdx-project.json                  ✅ Written
├── config/
│   └── project-scratch-def.json       ✅ Written
├── docs/
│   ├── specs/backlog/PRD.md           ✅ Written
│   ├── guides/user-guides/USAGE_GUIDE.md ✅ Written
│   ├── specs/backlog/REMAINING_TASKS.md  ✅ This file
│   └── images/                        ❌ Needs creation (see 2.2)
├── examples/                          ❌ Optional (see 3.2)
└── force-app/
    └── main/
        └── default/
            └── classes/
                ├── HierarchicalRecordCreator.cls           ✅ Written + deployed + tested
                ├── HierarchicalRecordCreator.cls-meta.xml  ✅ Written
                ├── HierarchicalRecordCreatorTest.cls       ✅ Written + 15/15 passing (93% coverage)
                └── HierarchicalRecordCreatorTest.cls-meta.xml ✅ Written
```

---

## Key Changes Made During Testing

### Savepoint/Rollback Fix

The original implementation relied on Apex's implicit transaction rollback (exception propagation causes the runtime to undo all DML). While this works correctly when invoked from a Flow, it does **not** roll back DML when the exception is caught in a test method's try/catch block.

**Fix applied:** Added `Database.setSavepoint()` before DML and `Database.rollback(sp)` in the catch block. This ensures explicit rollback regardless of calling context — Flow runtime, test harness, or direct Apex invocation. The exception is still re-thrown after rollback so the Flow's Fault connector continues to work correctly.

This is a best-practice improvement: explicit rollback is more defensive and testable than relying on implicit transaction semantics.
