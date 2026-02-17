# Usage Guide: Flow Hierarchical Record Creator

This guide walks through setting up the **Create Hierarchical Records** invocable action in a Salesforce Screen Flow. No code knowledge is required — everything is configured in Flow Builder.

---

## Prerequisites

- `HierarchicalRecordCreator` class deployed to your org
- `HierarchicalRecordCreatorTest` class deployed (required for production)
- Flow Builder access (System Administrator or equivalent permission)

---

## Concepts

### What is the index list?

Since Flow doesn't support Maps or nested objects, we use a **parallel index list** to express relationships. Each integer in the list is the **0-based position** of the parent record that the child at the same position belongs to.

Think of it like a two-column spreadsheet:

| Child Record    | Parent Index         |
| --------------- | -------------------- |
| Contact "Alice" | 0 (→ first Account)  |
| Contact "Bob"   | 0 (→ first Account)  |
| Contact "Carol" | 1 (→ second Account) |

You build this index list in Flow using a counter variable inside a Loop.

---

## Step-by-Step: Account → Contact (2 Levels)

### 1. Create Flow Variables

Create these variables in your Flow:

| Variable Name           | Type                        | Description                                      |
| ----------------------- | --------------------------- | ------------------------------------------------ |
| `varAccountCollection`  | Record Collection (Account) | Holds the parent Account records                 |
| `varContactCollection`  | Record Collection (Contact) | Holds the child Contact records                  |
| `varContactParentIndex` | Number Collection           | Maps each Contact to its parent Account position |
| `varParentCounter`      | Number (default: 0)         | Tracks the current parent's position             |
| `varParentIds`          | Text Collection             | Receives output parent IDs                       |
| `varChildIds`           | Text Collection             | Receives output child IDs                        |

### 2. Build Parent Records

Use Screen elements, Get Records, or any method to populate `varAccountCollection` with the Account records you want to create. Pre-populate all field values except `Id`.

### 3. Build Child Records with Index Mapping

For each parent, loop through its children:

```
Loop: For each parent Account
  │
  ├─ Loop: For each child Contact belonging to this parent
  │    ├─ Assignment: Set Contact fields (LastName, Email, etc.)
  │    ├─ Assignment: Add Contact to varContactCollection
  │    └─ Assignment: Add varParentCounter to varContactParentIndex
  │
  └─ Assignment: varParentCounter = varParentCounter + 1
```

The key insight: every Contact added during the inner loop gets the **same** `varParentCounter` value, which ties it to the current parent Account's position.

### 4. Add the Action Element

1. On the Flow canvas, click **+** and select **Action**.
2. Search for **"Create Hierarchical Records"**.
3. Configure inputs:

| Input                       | Value                      |
| --------------------------- | -------------------------- |
| Parent Records              | `{!varAccountCollection}`  |
| Child Records               | `{!varContactCollection}`  |
| Child Lookup Field API Name | `AccountId`                |
| Child-to-Parent Index Map   | `{!varContactParentIndex}` |

4. Configure outputs:

| Output            | Store In          |
| ----------------- | ----------------- |
| Parent Record IDs | `{!varParentIds}` |
| Child Record IDs  | `{!varChildIds}`  |

### 5. Add a Fault Connector

Click the Action element and add a **Fault** connector. Route it to a Screen that displays `{!$Flow.FaultMessage}` so users see a meaningful error if something goes wrong.

### 6. Use the Output IDs

After the action, `varParentIds` and `varChildIds` contain the newly created record IDs in the same order as your input collections. Use them for navigation, display, or further processing.

---

## Step-by-Step: 3 Levels (Account → Contact → Case)

Same as above, with an additional level:

### Additional Variables

| Variable Name       | Type                     | Description                                   |
| ------------------- | ------------------------ | --------------------------------------------- |
| `varCaseCollection` | Record Collection (Case) | Grandchild Case records                       |
| `varCaseChildIndex` | Number Collection        | Maps each Case to its parent Contact position |
| `varChildCounter`   | Number (default: 0)      | Tracks current child's position               |
| `varGrandchildIds`  | Text Collection          | Receives output grandchild IDs                |

### Building the Case Index

Similar to the child loop, but tracking the **child** position:

```
Loop: For each parent Account
  ├─ Loop: For each Contact under this Account
  │    ├─ Add Contact to varContactCollection
  │    ├─ Add varParentCounter to varContactParentIndex
  │    │
  │    ├─ Loop: For each Case under this Contact
  │    │    ├─ Add Case to varCaseCollection
  │    │    └─ Add varChildCounter to varCaseChildIndex
  │    │
  │    └─ varChildCounter = varChildCounter + 1
  │
  └─ varParentCounter = varParentCounter + 1
```

### Action Configuration (3 Levels)

| Input                            | Value                      |
| -------------------------------- | -------------------------- |
| Parent Records                   | `{!varAccountCollection}`  |
| Child Records                    | `{!varContactCollection}`  |
| Child Lookup Field API Name      | `AccountId`                |
| Child-to-Parent Index Map        | `{!varContactParentIndex}` |
| Grandchild Records               | `{!varCaseCollection}`     |
| Grandchild Lookup Field API Name | `ContactId`                |
| Grandchild-to-Child Index Map    | `{!varCaseChildIndex}`     |

---

## Field-Based Matching (Alternative to Index Lists)

Instead of building parallel index lists with counters, you can match children to parents by **field values**. This is especially useful when your records come from a data source with natural keys (external IDs, codes, email addresses, etc.).

### Concept

You tell the action which field on the child holds a "match key" and which field on the parent holds the corresponding unique value. The action matches them automatically.

```
Parent Accounts:
  Account "Alpha Inc"  → AccountNumber = "ALPHA-001"
  Account "Beta LLC"   → AccountNumber = "BETA-002"

Child Contacts:
  Contact "Alice"  → Department = "ALPHA-001"  → matches Alpha Inc
  Contact "Bob"    → Department = "ALPHA-001"  → matches Alpha Inc
  Contact "Carol"  → Department = "BETA-002"   → matches Beta LLC
```

### Step-by-Step: Field-Based Matching (Account → Contact)

#### 1. Create Flow Variables

| Variable Name          | Type                        | Description                                               |
| ---------------------- | --------------------------- | --------------------------------------------------------- |
| `varAccountCollection` | Record Collection (Account) | Parent Account records with a unique key field populated  |
| `varContactCollection` | Record Collection (Contact) | Child Contact records with a matching key field populated |
| `varParentIds`         | Text Collection             | Receives output parent IDs                                |
| `varChildIds`          | Text Collection             | Receives output child IDs                                 |

#### 2. Build Records with Match Keys

Populate each Account's key field (e.g., `AccountNumber`) and each Contact's corresponding field (e.g., `Department`) with matching values. No counters or index lists needed.

#### 3. Configure the Action

| Input                       | Value                     |
| --------------------------- | ------------------------- |
| Parent Records              | `{!varAccountCollection}` |
| Child Records               | `{!varContactCollection}` |
| Child Lookup Field API Name | `AccountId`               |
| Child Match Field           | `Department`              |
| Parent Match Field          | `AccountNumber`           |

> **Note:** Leave `Child-to-Parent Index Map` empty when using field-based matching. The two modes are mutually exclusive at each level.

#### 4. Rules to Follow

- **Parent key values must be unique.** If two Accounts have the same `AccountNumber`, the action will return an error.
- **Every child must have a match.** If a Contact's `Department` value doesn't match any Account's `AccountNumber`, the action will return an error.
- **No nulls or blanks.** All match field values must be populated on both sides.
- **Case-insensitive.** `ABC-001` will match `abc-001`.

### Mixing Modes Across Levels

You can use index-based mapping at one level and field-based matching at another. For example:

| Level                       | Mode        | Inputs                                                |
| --------------------------- | ----------- | ----------------------------------------------------- |
| Child (Account → Contact)   | Index-based | `childParentIndex`                                    |
| Grandchild (Contact → Case) | Field-based | `grandchildMatchField` + `grandchildParentMatchField` |

This is fully supported — just don't use both modes at the **same** level.

---

## Custom Objects Example

The action works with any object. For a custom hierarchy like `Order__c → Order_Line__c → Line_Schedule__c`:

| Input                            | Value                                                             |
| -------------------------------- | ----------------------------------------------------------------- |
| Parent Records                   | Collection of `Order__c` records                                  |
| Child Records                    | Collection of `Order_Line__c` records                             |
| Child Lookup Field API Name      | `Order__c` (the lookup field API name on Order_Line\_\_c)         |
| Child-to-Parent Index Map        | Index list                                                        |
| Grandchild Records               | Collection of `Line_Schedule__c` records                          |
| Grandchild Lookup Field API Name | `Order_Line__c` (the lookup field API name on Line_Schedule\_\_c) |
| Grandchild-to-Child Index Map    | Index list                                                        |

> **Important:** Use the **field API name**, not the relationship name. For custom lookups, this usually ends in `__c`. For standard lookups, it's the field name like `AccountId` or `ContactId`.

---

## Error Handling Best Practices

1. **Always add a Fault connector** on the Action element.
2. Display `{!$Flow.FaultMessage}` on an error screen so users know what went wrong.
3. Common errors and their causes:

| Error                                             | Cause                                                                                                               |
| ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| `parentRecords is required and must not be empty` | No parent records passed to the action.                                                                             |
| `childLookupField is required`                    | Provided child records but forgot to specify the lookup field name.                                                 |
| `must be the same size`                           | Your child collection and index list have different lengths. A child is missing its index or vice versa.            |
| `out of bounds`                                   | An index value points to a parent position that doesn't exist. Check your counter logic.                            |
| `Cannot use both`                                 | You provided both an index list and match fields at the same level. Use one approach or the other.                  |
| `must be provided together`                       | You provided only one of the match field pair. Both `childMatchField` and `parentMatchField` are required together. |
| `Duplicate ... value`                             | Two parent records have the same match field value. Parent-side values must be unique.                              |
| `does not match any parent-side`                  | A child record's match value doesn't correspond to any parent record. Check your key values.                        |
| `null or blank`                                   | A match field value is missing on a record. All match field values must be populated.                               |
| `REQUIRED_FIELD_MISSING`                          | A record is missing a required field value. Pre-populate all required fields before passing to the action.          |
| `FIELD_INTEGRITY_EXCEPTION`                       | A field value is invalid (wrong data type, picklist value, etc.).                                                   |

---

## Governor Limits

- The action performs **at most 3 DML statements** (one per level).
- Total records across all 3 levels must stay within Salesforce's **10,000 row DML limit** per transaction.
- Each level is inserted in a single bulk operation — no DML inside loops.

---

## FAQ

**Can I use this for just parent + grandchild (skipping child)?**
No. If you provide grandchild records, you must also provide child records. The grandchild lookup references the child, not the parent.

**Does this work with Person Accounts?**
Yes, as long as you pass the correct field API names for the lookup relationships.

**Can I call this from a Record-Triggered Flow?**
Yes. Wrap it in a Subflow Action element within the record-triggered flow.

**What about sharing rules?**
The class runs `with sharing` by default, respecting the running user's CRUD/FLS and sharing rules. If you need system context, modify the class to `without sharing` (requires developer assistance).
