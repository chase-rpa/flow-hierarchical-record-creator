# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.1.0] — 2026-02-17

### Added

- **Field-based matching** as an alternative to index-based mapping for child→parent wiring
  - `childMatchField` / `parentMatchField` — match children to parents by field value instead of position index
  - `grandchildMatchField` / `grandchildParentMatchField` — same for grandchild→child level
  - Case-insensitive matching (e.g., `ABC-001` matches `abc-001`)
- Validation for field-based matching: mutual exclusivity with index mode, duplicate parent key detection, unmatched child value detection, null/blank value detection
- Mixed mode support: index at one level, field match at another
- 10 new test methods (tests 19–28) covering field-based matching happy paths, error cases, case insensitivity, and rollback

## [1.0.0] — 2026-02-16

### Added

- `HierarchicalRecordCreator` invocable Apex action for Flow Builder
- Support for up to 3 levels of related records (parent → child → grandchild)
- Automatic lookup field wiring via index-based mapping
- Single atomic transaction with full rollback on any failure
- Input validation before DML (bounds checking, required field enforcement)
- Generic `SObject` handling — works with any standard or custom object
- `with sharing` enforcement for CRUD/FLS and sharing rule compliance
- Flow-native error handling via Fault connector
- 15-method test class (`HierarchicalRecordCreatorTest`) using Account/Contact/Case
- README with installation instructions and compatibility matrix
- Usage guide with step-by-step Flow Builder instructions
- MIT License
