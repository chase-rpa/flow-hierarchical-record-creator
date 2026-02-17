# Flow Hierarchical Record Creator

A generic Salesforce Flow Invocable Action that creates up to **3 levels of related records** (parent → child → grandchild) in a **single atomic transaction** — with automatic lookup field wiring between levels.

*By [Redpoint Ascent](https://redpointascent.com)*

## The Problem

Screen Flows defer DML until a commit point (a Screen element or flow end). This means when you create parent, child, and grandchild records in sequence, the **record IDs aren't available** to populate lookup fields on subsequent records. Your child and grandchild records get created without their lookup relationships.

Common workarounds either break atomicity (adding screens between creates) or rely on Aura components (UnofficialSF's CommitTransaction) that **don't work in LWR Digital Experience Sites**.

## The Solution

This invocable action accepts up to 3 collections of sObject records, inserts them in order, and automatically populates the lookup fields between levels using the record IDs generated from each insert. If anything fails at any level, the entire transaction rolls back — no orphaned records.

### Key Features

- **Generic** — Works with any standard or custom objects. No hardcoded references.
- **LWR Compatible** — Pure Apex. No Aura or LWC dependencies.
- **Atomic** — All-or-nothing. Full rollback on any failure.
- **Flow-native errors** — Failures surface on the Flow's Fault connector.
- **Bulk-safe** — Each level is inserted as a single bulk DML operation.

## Compatibility

| Environment | Supported |
|---|---|
| LWR Digital Experience Site | ✅ |
| Aura Digital Experience Site | ✅ |
| Lightning App (internal) | ✅ |
| Screen Flow | ✅ |
| Autolaunched Flow | ✅ |
| Record-Triggered Flow | ✅ |
| Salesforce Mobile App | ✅ |

## Install

### Option 1: SFDX Source Deploy

```bash
git clone https://github.com/redpointascent/flow-hierarchical-record-creator.git
cd flow-hierarchical-record-creator
sf project deploy start --source-dir force-app --target-org your-org-alias
```

### Option 2: Metadata API / Workbench

Deploy the contents of `force-app/main/default/classes/` to your org using Workbench, VS Code, or your preferred deployment tool.

### Option 3: Copy & Paste

Copy `HierarchicalRecordCreator.cls` and `HierarchicalRecordCreatorTest.cls` into your org via Developer Console or VS Code. Create the corresponding `-meta.xml` files with API version 58.0.

## Quick Start

1. Deploy the classes to your org.
2. Open your Screen Flow in Flow Builder.
3. Build your **parent record collection** (e.g., a list of Accounts).
4. Build your **child record collection** and a **parallel index list** mapping each child to its parent's position (0-based).
5. Add an **Action** element → search for **"Create Hierarchical Records"**.
6. Map your inputs.
7. Add a **Fault** connector to handle errors.

For a detailed walkthrough, see the [Usage Guide](docs/USAGE_GUIDE.md).

## Inputs

| Input | Type | Required | Description |
|---|---|---|---|
| `parentRecords` | `List<SObject>` | Yes | Level 1 records to insert |
| `childRecords` | `List<SObject>` | No | Level 2 records to insert |
| `childLookupField` | `String` | If children | API name of lookup field on child → parent |
| `childParentIndex` | `List<Integer>` | If children | 0-based index mapping each child to its parent |
| `grandchildRecords` | `List<SObject>` | No | Level 3 records to insert |
| `grandchildLookupField` | `String` | If grandchildren | API name of lookup field on grandchild → child |
| `grandchildParentIndex` | `List<Integer>` | If grandchildren | 0-based index mapping each grandchild to its child |

## Outputs

| Output | Type | Description |
|---|---|---|
| `parentIds` | `List<Id>` | IDs of inserted parents (same order as input) |
| `childIds` | `List<Id>` | IDs of inserted children (same order as input) |
| `grandchildIds` | `List<Id>` | IDs of inserted grandchildren (same order as input) |
| `isSuccess` | `Boolean` | `true` if all inserts succeeded |
| `errorMessage` | `String` | Exception details on failure |

## How the Index Mapping Works

The index list is a parallel collection where each value is the **0-based position** of the parent record that the child belongs to.

**Example:** 2 Accounts, 5 Contacts (3 under Account 0, 2 under Account 1):

```
parentRecords:    [ Account-A,  Account-B ]
                     index 0     index 1

childRecords:     [ Contact-1, Contact-2, Contact-3, Contact-4, Contact-5 ]
childParentIndex: [     0,         0,         0,         1,         1     ]
```

Contacts 1–3 get `AccountId = Account-A.Id`, Contacts 4–5 get `AccountId = Account-B.Id`.

## License

[MIT](LICENSE)

## Contributing

Issues and pull requests welcome. Please include test coverage for any new functionality.
