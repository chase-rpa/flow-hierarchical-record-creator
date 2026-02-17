# Remaining Tasks — Hierarchical Record Creator

**Last updated:** February 16, 2026
**Status:** Core implementation complete. Ready for validation, polish, and release.

This document outlines all remaining work for another agent or developer to bring this project from "code complete" to "publicly released." Tasks are grouped by priority.

---

## Priority 1 — Must Complete Before Release

### 1.1 Deploy & Run Tests in a Scratch Org

The Apex classes have been written but **not yet deployed or tested against a live Salesforce org**. This is the most critical next step.

- [ ] Create a scratch org: `sf org create scratch -f config/project-scratch-def.json -a hrc-test`
- [ ] Deploy: `sf project deploy start --source-dir force-app --target-org hrc-test`
- [ ] Run tests: `sf apex run test --class-names HierarchicalRecordCreatorTest --target-org hrc-test --result-format human --code-coverage`
- [ ] Confirm all 15 test methods pass
- [ ] Confirm code coverage ≥ 75% (target 90%+)
- [ ] Fix any compilation errors or test failures
- [ ] **Note:** A `project-scratch-def.json` file needs to be created in a `config/` directory. Minimal example:

```json
{
  "orgName": "HRC Scratch Org",
  "edition": "Developer",
  "features": [],
  "settings": {
    "lightningExperienceSettings": {
      "enableS1DesktopEnabled": true
    }
  }
}
```

### 1.2 Validate Rollback Behavior

Test 6 (`testRollbackOnChildFailure`) validates rollback when a child DML fails. The following needs manual verification:

- [ ] In a scratch org, create a Screen Flow using the action with intentionally bad data at each level
- [ ] Confirm that when Level 2 (child) insert fails, Level 1 (parent) records do NOT persist
- [ ] Confirm that when Level 3 (grandchild) insert fails, Level 1 and Level 2 records do NOT persist
- [ ] Confirm the Flow's Fault connector receives the error message

### 1.3 Validate LWR Digital Experience Compatibility

This is the primary use case. Must be tested end-to-end.

- [ ] Enable Digital Experiences in the scratch org
- [ ] Create an LWR-based Digital Experience Site (e.g., "Build Your Own" LWR template)
- [ ] Create a Screen Flow that uses the "Create Hierarchical Records" action
- [ ] Embed the Screen Flow in the LWR site (via Flow component on a page)
- [ ] Run the flow as a site user (community/experience user profile)
- [ ] Confirm all 3 levels are created with correct lookup wiring
- [ ] Confirm fault handling works in the LWR context
- [ ] **Sharing context note:** The class uses `with sharing`. If the experience user doesn't have Create access on the target objects, the DML will fail. This is expected behavior — document it if it comes up during testing.

### 1.4 Test Coverage Gaps to Address

Review and potentially add coverage for:

- [ ] **Grandchild-level DML rollback:** Test 7 (`testRollbackOnGrandchildFailure`) currently succeeds because the test data doesn't trigger a DML failure at the grandchild level. Consider adding a validation rule on Case in the test setup (or use a `@TestSetup` with a custom validation rule via metadata) to force a grandchild-level failure and verify full rollback. Alternatively, test with an invalid field value that causes a DML error.
- [ ] **Null index value in list:** Add a test where one entry in `childParentIndex` is `null`. The current `validateIndexBounds` method checks for null but this isn't explicitly tested.
- [ ] **Large volume test:** Add a test with 200 parents, 1000 children, 2000 grandchildren to verify bulk behavior and governor limit compliance.

---

## Priority 2 — Should Complete Before Release

### 2.1 Create `project-scratch-def.json`

- [ ] Add `config/project-scratch-def.json` to the repo (see template in 1.1 above)
- [ ] Verify scratch org creation works cleanly

### 2.2 GitHub Repository Setup

- [ ] Create public repo at `github.com/redpointascent/flow-hierarchical-record-creator`
- [ ] Push all files from the `flow-hierarchical-record-creator/` directory
- [ ] Set default branch to `main`
- [ ] Add repo description: "Generic Salesforce Flow invocable action to create parent → child → grandchild records in a single atomic transaction with automatic lookup wiring. Pure Apex — LWR compatible. By Redpoint Ascent."
- [ ] Add topics: `salesforce`, `apex`, `flow`, `invocable-action`, `lwr`, `digital-experience`, `screen-flow`
- [ ] Verify the README renders correctly on GitHub

### 2.3 Add CHANGELOG.md

- [ ] Create `CHANGELOG.md` in repo root with initial v1.0 entry listing features delivered

### 2.4 Review InvocableVariable Annotations

Flow Builder displays the `label` and `description` from `@InvocableVariable` annotations. These need to be verified in-context:

- [ ] Open a Flow in Flow Builder and add the "Create Hierarchical Records" action
- [ ] Verify all input labels and descriptions are clear and readable in the property editor
- [ ] Verify output labels make sense when storing results
- [ ] Adjust wording if anything is confusing to a non-developer admin

### 2.5 Usage Guide Screenshots

The `docs/USAGE_GUIDE.md` references Flow Builder steps but has no screenshots.

- [ ] Add screenshots showing:
  - The Action element search result for "Create Hierarchical Records"
  - The input configuration panel with all fields mapped
  - The output configuration panel
  - A Fault connector wired to an error screen
  - A complete example flow canvas (2-level and 3-level)
- [ ] Store screenshots in `docs/images/` directory
- [ ] Update USAGE_GUIDE.md with `![description](images/filename.png)` references

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

Verify all of the following exist in the repo before release:

```
flow-hierarchical-record-creator/
├── README.md                          ✅ Written
├── LICENSE                            ✅ Written (MIT)
├── .gitignore                         ✅ Written
├── sfdx-project.json                  ✅ Written
├── config/
│   └── project-scratch-def.json       ❌ Needs creation (see 2.1)
├── docs/
│   ├── PRD.md                         ✅ Written
│   ├── USAGE_GUIDE.md                 ✅ Written
│   ├── REMAINING_TASKS.md             ✅ This file
│   └── images/                        ❌ Needs creation (see 2.5)
├── CHANGELOG.md                       ❌ Needs creation (see 2.3)
├── examples/                          ❌ Optional (see 3.2)
└── force-app/
    └── main/
        └── default/
            └── classes/
                ├── HierarchicalRecordCreator.cls           ✅ Written
                ├── HierarchicalRecordCreator.cls-meta.xml  ✅ Written
                ├── HierarchicalRecordCreatorTest.cls       ✅ Written
                └── HierarchicalRecordCreatorTest.cls-meta.xml ✅ Written
```

---

## Context for the Next Agent

### What's been done
- Full PRD written and reviewed with the project owner (Chase @ Redpoint Ascent)
- Apex invocable class implemented with generic sObject handling, input validation, 3-level insert with automatic lookup wiring, and transaction rollback
- Test class with 15 test methods covering happy paths, rollback scenarios, and all validation error cases
- README, Usage Guide, MIT License, sfdx-project.json, and .gitignore created
- All code reviewed for Flow compatibility and LWR compatibility (no Aura/LWC dependencies)

### What hasn't been done
- **Nothing has been deployed to a Salesforce org yet.** Code was written outside of Salesforce and needs to be deployed and tested.
- No screenshots exist for the Usage Guide
- No unmanaged package install link has been generated
- No sample flow metadata has been created

### Key design decisions to be aware of
- **Index-based mapping** was chosen because Flow doesn't support Maps. The parallel index list pattern is the most practical approach despite being slightly verbose for admins.
- **`with sharing`** is the default because this targets Digital Experience Sites where guest/community users should have restricted access.
- **Exceptions are re-thrown** rather than caught and returned as error messages. This is intentional — it lets the Flow's Fault connector work properly and ensures Apex rolls back the transaction.
- **Standard objects in tests** (Account, Contact, Case) to keep the package dependency-free. The actual class uses `SObject` generically and works with any object.
