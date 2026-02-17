# Salesforce Scratch Org Setup Guide

This guide outlines the process to create and configure scratch orgs for Redpoint Ascent development.

---

## Overview

Scratch orgs are temporary Salesforce environments used for development and testing. This guide covers how to create scratch orgs using the standard Redpoint Ascent configuration.

---

## Prerequisites

- Salesforce CLI: Latest version of `sf` CLI installed
- Dev Hub Access: Authenticated to the Redpoint Ascent Dev Hub
- Project Setup: Local clone of the Redpoint Ascent repository

---

## Naming Convention

Use the following naming pattern for scratch orgs:

```
rpa-so-{descriptor}
```

Where `{descriptor}` is a one to two word description of the org's purpose.

**Examples:**

- `rpa-so-security` - Security review testing
- `rpa-so-crud` - CRUD/FLS validation work
- `rpa-so-webhook` - Webhook feature development
- `rpa-so-bugfix` - General bug fixing
- `rpa-so-release` - Release validation

---

## Creating a Scratch Org

### Step 1: Authenticate to the Dev Hub

If not already authenticated:

```bash
sf org login web --alias rpa-devhub --set-default-dev-hub
```

### Step 2: Create the Scratch Org

Use the standard Redpoint Ascent scratch org definition file with default duration (7 days):

```bash
sf org create scratch --definition-file config/project-scratch-def.json --alias rpa-so-{descriptor} --set-default --target-dev-hub rpa-dev-hub
```

**Example:**

```bash
sf org create scratch --definition-file config/project-scratch-def.json --alias rpa-so-security --set-default --target-dev-hub rpa-dev-hub
```

### Step 3: Push Source to the Org

```bash
sf project deploy start
```

### Step 4: Open the Scratch Org

```bash
sf org open --target-org rpa-so-{descriptor}
```

---

## Scratch Org Configuration Details

The `config/project-scratch-def.json` definition creates orgs with:

| Setting     | Value       |
| ----------- | ----------- |
| Org Name    | rpa_scratch |
| Edition     | Enterprise  |
| Country     | US          |
| Language    | en_US       |
| Sample Data | Yes         |
| Features    | API         |

---

## Managing Scratch Orgs

### List All Scratch Orgs

```bash
sf org list --all
```

### Check Org Status

```bash
sf org display --target-org rpa-so-{descriptor}
```

### Delete a Scratch Org

```bash
sf org delete scratch --target-org rpa-so-{descriptor} --no-prompt
```

---

## Quick Reference

| Action             | Command                                                                                                                                          |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| Create scratch org | `sf org create scratch --definition-file config/project-scratch-def.json --alias rpa-so-{descriptor} --set-default --target-dev-hub rpa-dev-hub` |
| Push source        | `sf project deploy start`                                                                                                                        |
| Open org           | `sf org open --target-org rpa-so-{descriptor}`                                                                                                   |
| List orgs          | `sf org list --all`                                                                                                                              |
| Delete org         | `sf org delete scratch --target-org rpa-so-{descriptor} --no-prompt`                                                                             |

---

## Troubleshooting

### Error: "No default Dev Hub org found"

Authenticate to the Dev Hub:

```bash
sf org login web --alias rpa-devhub --set-default-dev-hub
```

### Error: "Scratch org creation failed"

- Verify you have available scratch org allocations in the Dev Hub
- Check that the definition file exists at `config/project-scratch-def.json`
- Ensure you have the required permissions in the Dev Hub

### Error: "Definition file not found"

Run the command from the project root directory where the `config` folder is located.

---

## Version History

| Date       | Author | Changes         |
| ---------- | ------ | --------------- |
| 2026-01-29 | -      | Initial version |
