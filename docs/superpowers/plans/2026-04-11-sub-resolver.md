# v5 Schema Rename + partitionBy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rename v4 schema fields to v5 naming convention (pipeline-ordered, clear separation of concerns) and implement selector.partitionBy for nested grouping.

**Architecture:** Fields are renamed to follow the processing pipeline: episodeFilters -> grouping -> selector -> display (groupListing/groupItem/episodeListing/episodeItem). V4 names kept as serde aliases and Zod preprocess migrations. Selector.partitionBy enables organizing groups into season or year partitions.

**Tech Stack:** Rust (sp_core, sp_server), TypeScript/React (sp_react), JSON Schema, Zod

**Working directory:** `/Users/tohru/Documents/src/ghq/github.com/audiflow/audiflow-smartplaylist-editor`

**Base:** Builds on existing feat/v5 commits (SelectorConfig, sub_groups, partitionBy logic already implemented with intermediate names).

---

## Remaining Work

The feat/v5 branch already has:
- SelectorConfig with partitionBy (selector field on PlaylistDefinition)
- sub_groups on PlaylistGroup
- partition_groups_by_season / partition_groups_by_year in ResolverService
- Preview API sub_groups serialization
- Zod selectorConfigSchema + recursive previewGroupSchema
- React SubGroupList component

What's left:
1. Rename Rust models to v5 names (grouping, groupItem, etc.)
2. Rename JSON Schema to v5 names
3. Rename Zod schemas to v5 names
4. Update React components for new field names
5. Update all tests
6. Full verification
