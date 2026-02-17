# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Salesforce Flow invocable Apex action that creates parent → child → grandchild record hierarchies in a single atomic transaction with automatic lookup field wiring. Solves the limitation where Screen Flows defer DML, making parent IDs unavailable for child lookup fields before commit.

Primary target: LWR Digital Experience Sites (no Aura/LWC dependencies — pure Apex).

## Commands

```bash
# Lint (JS in aura/lwc directories)
npm run lint

# Format all files
npm run prettier

# Check formatting without changes
npm run prettier:verify

# Run LWC Jest tests
npm run test:unit

# Run tests in watch mode
npm run test:unit:watch

# Run tests with coverage
npm run test:unit:coverage

# Deploy to default org
sf project deploy start --source-dir force-app

# Run Apex tests in org
sf apex run test --test-level RunLocalTests --result-format human

# Run a specific Apex test class in org
sf apex run test --class-names HierarchicalRecordCreatorTest --result-format human

# Create scratch org from config
sf org create scratch --definition-file config/project-scratch-def.json --set-default --alias flow-hier-creator
```

Pre-commit hook (Husky + lint-staged) auto-formats staged files on commit.

## Architecture

### Core Files

- **`force-app/main/default/classes/HierarchicalRecordCreator.cls`** — Single invocable class (~267 lines). Entry point: `createRecords(List<Request>)` annotated with `@InvocableMethod`. Uses generic `SObject.put(fieldName, value)` — no hardcoded object or field names.
- **`force-app/main/default/classes/HierarchicalRecordCreatorTest.cls`** — 15 test methods (~493 lines) using Account/Contact/Case as test hierarchy.

### How It Works

1. Flow passes parent records, child records, lookup field API names, and **index mapping lists**
2. Action inserts parents → captures IDs → wires child lookups using index mapping → inserts children → repeats for grandchildren
3. Returns all generated IDs back to the Flow; any failure rolls back the entire transaction

### Index Mapping Pattern

Flow lacks Map/dictionary support, so child→parent relationships use parallel integer lists:
```
children: [Contact-1, Contact-2, Contact-3]
indices:  [0,         0,         1]
→ Contact-1 and Contact-2 belong to parent[0], Contact-3 to parent[1]
```

### Key Design Decisions

- **`with sharing`** — respects user CRUD/FLS and sharing rules
- **Validation before DML** — all inputs validated before any insert; prevents orphaned records
- **Max 3 DML statements** per invocation (one per level) — governor-limit compliant
- **Exceptions re-thrown** so Flow's Fault connector handles errors and transaction auto-rolls back
- **3 levels max** (parent/child/grandchild) — deeper hierarchies can chain multiple invocations

## Salesforce DX Config

- **Source API version:** 65.0 (`sfdx-project.json`)
- **Source path:** `force-app/` (single package directory)
- **Scratch org definition:** `config/project-scratch-def.json`

## Documentation

- `docs/guides/user-guides/USAGE_GUIDE.md` — Step-by-step Flow Builder instructions for admins
- `docs/specs/backlog/PRD.md` — Full product requirements and design rationale
- `docs/specs/backlog/REMAINING_TASKS.md` — Deployment checklist and enhancement candidates
