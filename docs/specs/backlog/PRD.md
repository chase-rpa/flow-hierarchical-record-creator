# PRD: Hierarchical Record Creator — Flow Invocable Action

**Project:** `flow-hierarchical-record-creator`
**Version:** 1.0
**Date:** February 16, 2026
**Author:** Redpoint Ascent

---

## 1. Problem Statement

Salesforce Screen Flows defer all DML operations until a commit point (a Screen element or the end of the flow). This means that when creating parent, child, and grandchild records in sequence, the record IDs from earlier Create Records elements are **not available** to populate lookup fields on subsequent records — because the records haven't actually been committed to the database yet.

### Current Workarounds and Why They Fail

| Approach | Issue |
|---|---|
| **Add a Screen element between creates** | Forces a commit, but breaks the single transaction — partial creates cannot be rolled back together. Also degrades UX with unnecessary screens. |
| **UnofficialSF CommitTransaction action** | Implemented as an Aura-based Local Action. **Aura components are not supported in LWR Digital Experience Sites**, making this unusable in modern Experience Cloud builds. |
| **Autolaunched Subflow** | Subflows run in the same transaction as the parent and share the same deferred DML behavior. Does not solve the ID availability problem. |

### The Core Tension

- **Getting IDs** requires a DML commit.
- **Atomic rollback** requires a single transaction with no intermediate commits.
- These two requirements are mutually exclusive in declarative Screen Flows.

**Apex resolves this** because `insert` statements execute DML immediately, making record IDs available in-memory without requiring a Flow-level commit boundary. A single Apex method wrapped in implicit transaction handling provides both immediate IDs and full rollback on failure.

---

## 2. Proposed Solution

A **generic, reusable Apex Invocable Action** (`HierarchicalRecordCreator`) that accepts up to three levels of sObject records, automatically wires lookup relationships between levels using admin-specified field API names, and inserts all records within a single Apex transaction.

### Key Design Principles

- **Generic** — Works with any combination of standard and custom objects. No hardcoded object or field references.
- **Declarative-first** — Designed to be consumed entirely from Flow Builder with no code knowledge required by the admin.
- **LWR-compatible** — Pure Apex with no Aura or LWC dependencies. Safe for use in LWR Digital Experience Sites, Aura Experience Sites, and internal Lightning pages.
- **Atomic** — All-or-nothing. If any insert fails at any level, all previously inserted records in the same invocation are rolled back via standard Apex exception handling.
- **Flow-native error handling** — On failure, throws an `InvocableActionException` (or unhandled exception) that surfaces on the Flow's Fault connector, enabling admins to build fault paths as they would with any other Flow action.

---

## 3. Functional Requirements

### 3.1 Inputs

The invocable action accepts the following inputs per invocation. All inputs are set via the Flow Action element's property editor.

| Input | Type | Required | Description |
|---|---|---|---|
| `parentRecords` | `List<SObject>` | **Yes** | Collection of Level 1 (parent) records to insert. All field values except `Id` should be pre-populated by the Flow prior to invocation. |
| `childRecords` | `List<SObject>` | No | Collection of Level 2 (child) records to insert. |
| `childLookupField` | `String` | Required if `childRecords` provided | API name of the lookup field on the child object that references the parent (e.g., `AccountId`, `Parent_Order__c`). |
| `childParentIndex` | `List<Integer>` | Required if `childRecords` provided | A parallel list to `childRecords` where each integer is the **0-based index** of the parent record in `parentRecords` that the child should be linked to. |
| `grandchildRecords` | `List<SObject>` | No | Collection of Level 3 (grandchild) records to insert. |
| `grandchildLookupField` | `String` | Required if `grandchildRecords` provided | API name of the lookup field on the grandchild object that references the child (e.g., `ContactId`, `Order_Line__c`). |
| `grandchildParentIndex` | `List<Integer>` | Required if `grandchildRecords` provided | A parallel list to `grandchildRecords` where each integer is the **0-based index** of the child record in `childRecords` that the grandchild should be linked to. |

> **Why index-based mapping?** Flow does not support Maps or complex nested structures natively. Parallel index lists are the most practical way to express "this child belongs to that parent" within Flow's variable system. Admins build the index list inside a Loop using an Assignment element and a counter variable.

### 3.2 Outputs

| Output | Type | Description |
|---|---|---|
| `parentIds` | `List<Id>` | IDs of the inserted parent records, in the same order as the input `parentRecords`. |
| `childIds` | `List<Id>` | IDs of the inserted child records, in the same order as the input `childRecords`. |
| `grandchildIds` | `List<Id>` | IDs of the inserted grandchild records, in the same order as the input `grandchildRecords`. |
| `isSuccess` | `Boolean` | `true` if all inserts succeeded. `false` should not occur (failures throw exceptions for fault handling), but included for defensive Flow logic. |
| `errorMessage` | `String` | Populated with the exception message if an error occurs. Empty on success. |

### 3.3 Execution Flow

```
1. Validate inputs
   ├── parentRecords must not be empty
   ├── If childRecords provided → childLookupField and childParentIndex are required
   ├── If grandchildRecords provided → grandchildLookupField and grandchildParentIndex are required
   ├── Index lists must be same size as their corresponding record lists
   └── All index values must be within bounds of their parent list

2. Insert parentRecords
   └── IDs now available on each SObject in the list

3. Wire child lookups
   ├── For each childRecord[i], set childLookupField = parentRecords[childParentIndex[i]].Id
   └── Insert childRecords

4. Wire grandchild lookups
   ├── For each grandchildRecord[i], set grandchildLookupField = childRecords[grandchildParentIndex[i]].Id
   └── Insert grandchildRecords

5. Return all IDs

On ANY DmlException or other exception:
   └── Apex implicit transaction rollback undoes ALL inserts
   └── Exception propagates to Flow → surfaces on Fault connector
```

### 3.4 Supported Configurations

| Scenario | parentRecords | childRecords | grandchildRecords |
|---|---|---|---|
| Parent only | ✅ | — | — |
| Parent + Child | ✅ | ✅ | — |
| Parent + Child + Grandchild | ✅ | ✅ | ✅ |

> **Grandchild without Child is not supported.** If `grandchildRecords` is provided, `childRecords` must also be provided. The action validates this and throws a descriptive error.

### 3.5 Error Handling

- **Validation errors** (missing required inputs, out-of-bounds indices): Throw an `IllegalArgumentException` with a descriptive message before any DML occurs.
- **DML errors** (duplicate rules, validation rules, required field missing, trigger exceptions): The `DmlException` propagates unhandled, causing Apex to roll back all DML in the transaction. The Flow receives the error on its Fault connector.
- **Unexpected errors**: Any uncaught `Exception` rolls back the transaction and surfaces on the Fault connector.

Admins should **always add a Fault connector** on the Action element in their Flow to handle errors gracefully (e.g., display error screen, log to custom object, send notification).

---

## 4. Non-Functional Requirements

| Requirement | Detail |
|---|---|
| **Governor Limits** | The action performs a maximum of 3 DML statements per invocation (one per level). Admins must ensure the total record count stays within Salesforce DML row limits (10,000 rows per transaction). |
| **Bulkification** | Each level is inserted as a single bulk DML operation. No DML inside loops. |
| **API Version** | Minimum API version 58.0 (Summer '23) for broadest LWR compatibility. |
| **Namespace** | Unpackaged / no namespace. Designed for source-deploy into any org. |
| **Test Coverage** | Minimum 75% Apex code coverage. Target 90%+. |
| **Security** | Runs in `with sharing` context by default. Respects the running user's CRUD/FLS and sharing rules. Admins may change to `without sharing` if the use case requires system-level access. |

---

## 5. Test Plan

### Test Class: `HierarchicalRecordCreatorTest`

| # | Test Method | Description | Validates |
|---|---|---|---|
| 1 | `testParentOnlyInsert` | Insert a collection of Accounts with no children. | Parents created, IDs returned, isSuccess = true. |
| 2 | `testParentAndChildInsert` | Insert Accounts (parents) and Contacts (children) with lookup wiring. | Child `AccountId` populated correctly. Both ID lists returned. |
| 3 | `testThreeLevelInsert` | Insert Accounts → Contacts → Cases (or custom objects). | All three levels created with correct lookup chain. |
| 4 | `testMultipleParentsWithChildren` | 3 parents, 2 children each, mapped via index list. | Index mapping correctly associates each child to its parent. |
| 5 | `testRollbackOnChildFailure` | Insert valid parents, then children with a field that triggers a validation rule or required field violation. | No parent records persist (rolled back). Exception surfaces. |
| 6 | `testRollbackOnGrandchildFailure` | Insert valid parents and children, then grandchildren that fail. | No parent or child records persist. Exception surfaces. |
| 7 | `testMissingChildLookupField` | Provide `childRecords` but omit `childLookupField`. | `IllegalArgumentException` thrown with descriptive message. |
| 8 | `testIndexOutOfBounds` | Provide `childParentIndex` with a value exceeding `parentRecords.size()`. | `IllegalArgumentException` thrown before any DML. |
| 9 | `testGrandchildWithoutChild` | Provide `grandchildRecords` without `childRecords`. | `IllegalArgumentException` thrown with descriptive message. |
| 10 | `testEmptyParentList` | Pass an empty `parentRecords` list. | `IllegalArgumentException` thrown. |

> **Note on test objects:** Tests should use standard objects (Account, Contact, Case) to avoid org-specific custom object dependencies. This keeps the package portable across orgs.

---

## 6. Repository Structure

```
flow-hierarchical-record-creator/
├── README.md
├── LICENSE (MIT)
├── docs/
│   └── USAGE_GUIDE.md
├── force-app/
│   └── main/
│       └── default/
│           └── classes/
│               ├── HierarchicalRecordCreator.cls
│               ├── HierarchicalRecordCreator.cls-meta.xml
│               ├── HierarchicalRecordCreatorTest.cls
│               └── HierarchicalRecordCreatorTest.cls-meta.xml
├── sfdx-project.json
└── .gitignore
```

---

## 7. Usage Guide (Summary)

*Full guide to be published in `docs/USAGE_GUIDE.md`.*

### Quick Start

1. **Deploy** the `HierarchicalRecordCreator` class to your org via SFDX, Workbench, or Change Set.
2. In Flow Builder, open your Screen Flow.
3. **Build your record collections** using Assignment elements inside Loops (or however you currently collect user input).
4. **Build your index lists** — for each child, append the position (0-based) of its parent in the parent collection.
5. Add an **Action** element → search for `Create Hierarchical Records`.
6. Map your inputs: parent collection, child collection, child lookup field API name, child index list, and optionally grandchild equivalents.
7. Add a **Fault** connector on the Action element to handle errors.
8. Use the output `parentIds`, `childIds`, and `grandchildIds` collections downstream as needed.

### Example: Order → Order Lines → Line Schedules

```
Inputs:
  parentRecords       → {!OrderCollection}           (List<Order>)
  childRecords        → {!OrderLineCollection}       (List<Order_Line__c>)
  childLookupField    → "Order__c"
  childParentIndex    → {!OrderLineParentIndexList}   (List<Integer>)  [0, 0, 1, 1, 1]
  grandchildRecords   → {!LineScheduleCollection}    (List<Line_Schedule__c>)
  grandchildLookupField → "Order_Line__c"
  grandchildParentIndex → {!ScheduleChildIndexList}  (List<Integer>)  [0, 1, 2, 3, 4]
```

This creates 2 Orders, 5 Order Lines (2 under Order 0, 3 under Order 1), and 5 Line Schedules (one per Order Line) — all in a single atomic transaction.

---

## 8. Documentation Deliverables

| Document | Location | Audience |
|---|---|---|
| **README.md** | Repository root | Developers, admins discovering the repo. Overview, install instructions, compatibility notes. |
| **USAGE_GUIDE.md** | `docs/` | Salesforce admins. Step-by-step Flow Builder walkthrough with screenshots (post-implementation). |
| **Inline Apex comments** | Source files | Developers. Method-level and block-level comments explaining logic. |
| **This PRD** | Repository root or `docs/` | Contributors, reviewers, maintainers. |

---

## 9. Compatibility Matrix

| Environment | Supported | Notes |
|---|---|---|
| LWR Digital Experience Site | ✅ | Primary target. Pure Apex, no Aura dependency. |
| Aura Digital Experience Site | ✅ | |
| Lightning App (internal) | ✅ | |
| Screen Flow | ✅ | Primary use case. |
| Autolaunched Flow | ✅ | Works but less common since autolaunched flows don't have the deferred DML issue in the same way. |
| Record-Triggered Flow | ✅ | Can be called as a subflow action. |
| Mobile (Salesforce Mobile App) | ✅ | |
| Flow Orchestration | ✅ | Can be used within interactive steps. |

---

## 10. Open Questions & Future Considerations

| # | Topic | Status |
|---|---|---|
| 1 | **Should we support a 4th level?** Current design stops at 3 (parent/child/grandchild). Could be extended but adds complexity to the index mapping. | Deferred — 3 levels covers the vast majority of use cases. |
| 2 | **Should we support mixed parent mapping for grandchildren?** (e.g., some grandchildren look up to parent instead of child) | Out of scope for v1. Admins can call the action multiple times for different relationship patterns. |
| 3 | **Should we add a `runInSystemContext` boolean input?** Would allow admins to toggle `with sharing` / `without sharing` behavior. | Deferred — security implications need review. For v1, ship `with sharing` and let orgs fork if needed. |
| 4 | **Managed package vs. unmanaged?** | Ship as unmanaged / source-deploy. Lower friction for open-source consumption. Revisit if AppExchange listing is desired. |
| 5 | **Support for upsert instead of insert?** | Deferred to v2. Insert-only for v1 keeps the scope tight. |

---

## 11. Success Criteria

- [ ] All 10 test methods pass.
- [ ] Code coverage ≥ 75% (target 90%+).
- [ ] Deploys cleanly to a scratch org with no dependencies.
- [ ] Successfully creates a 3-level hierarchy from a Screen Flow in an LWR Digital Experience Site.
- [ ] On failure at any level, zero records persist (full rollback confirmed).
- [ ] Fault connector in Flow receives the error message.
- [ ] README and Usage Guide published in repo.
