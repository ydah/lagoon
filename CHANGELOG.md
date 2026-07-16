# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## 0.2.0 - 2026-07-16

- Added structured generation results with content, warnings, and counts.
- Added application-only discovery, strict analysis, configurable current-principal helpers, multi-database ER generation, and atomic output.
- Fixed all declared CLI and Rake options, including brief, exclude/specify, all-models, hide-magic, and hide-types.
- Fixed ER relationship direction and cardinality using actual foreign key, primary key, unique index, and nullability metadata.
- Changed controller-model output to UML dependency relationships and expanded AST analysis for callbacks, helper methods, namespaces, local variables, and association chains.
- Added Prism as a runtime dependency while retaining lazy AST loading.
- Added Ruby/Rails/adapter CI matrices, end-to-end Rails coverage, Mermaid parser validation, package smoke tests, linting, and RBS validation.

## 0.1.0 - 2025-12-17

- Initial release
