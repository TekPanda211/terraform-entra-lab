# ARCHITECTURE.md

This should become the technical blueprint.

```markdown
# Blackknight One Architecture

## Platform Overview

Blackknight One is organized into three layers.

Configuration

↓

Platform Services

↓

Engines

↓

Reports

↓

Confidence

---

## Configuration

Platform behavior is controlled through the configuration directory.

Examples:

- platform.json
- engines.json
- logging.json
- reporting.json

---

## Platform Services

Platform Services provide reusable capabilities.

Current services:

- Configuration
- Logging
- Reporting
- Confidence

Future services:

- Microsoft Graph
- Authentication
- Plugin Management
- HTML Reporting
- Markdown Reporting

---

## Engine Model

Each engine should:

Discover

↓

Measure

↓

Validate

↓

Produce Evidence

↓

Return Standard Result Schema

---

## Platform Confidence

Each engine returns its own confidence score.

The Core Engine aggregates those results into a platform confidence score.

---

## North Star

Every engine answers one question.

> Can I trust the current state of my environment?