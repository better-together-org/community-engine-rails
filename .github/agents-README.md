# GitHub Copilot Instructions

This directory contains instruction files that help GitHub Copilot understand how to work with this repository.

## Instruction System Overview

This repository uses a three-tier instruction system to provide comprehensive guidance to GitHub Copilot and other AI coding assistants:

### 1. Repository-Wide Instructions
**File**: [`copilot-instructions.md`](copilot-instructions.md)
- Applies to all files in the repository
- Contains core architectural principles, coding standards, and patterns
- Includes technology stack overview, documentation policies, and testing guidelines
- **When to use**: Understanding overall architecture, coding style, and project-wide conventions

### 2. Agent-Specific Instructions  
**File**: [`../AGENTS.md`](../AGENTS.md) (repository root)
- Detailed command reference and test execution workflows
- Docker environment setup and debugging practices
- Comprehensive testing guidelines and common patterns
- **When to use**: Running commands, executing tests, debugging issues, understanding development workflows

### 3. Path-Specific Instructions
**Directory**: [`instructions/`](instructions/)
- Technology-specific guidelines that apply to particular file types
- Automatically loaded based on file path glob patterns
- 13 specialized instruction files covering different technologies
- **When to use**: Working with specific technologies (Hotwire, accessibility, i18n, etc.)

## Quick Navigation

### For Developers
- **Setting up the project**: See [AGENTS.md](../AGENTS.md) → Setup section
- **Running tests**: See [AGENTS.md](../AGENTS.md) → Test Commands section
- **Code style and patterns**: See [copilot-instructions.md](copilot-instructions.md) → Core Principles
- **Technology-specific help**: Browse [instructions/README.md](instructions/README.md)

### For Copilot/AI Assistants
When you receive a request:
1. Check which files are being modified
2. Load relevant path-specific instructions from `instructions/` directory
3. Apply repository-wide principles from `copilot-instructions.md`
4. Reference `AGENTS.md` for command execution and testing guidance

## Instruction Files

### Repository-Wide
- **copilot-instructions.md** (624+ lines)
  - Core principles and technology stack
  - Documentation and diagram standards
  - Coding guidelines (accessibility, debugging, security, testing)
  - Timezone management
  - Common issues and solutions

### Agent Instructions
- **../AGENTS.md** (960+ lines)
  - Project setup and environment
  - Test execution guidelines (CRITICAL section)
  - Security requirements and conventions
  - String enum and migration standards
  - Database query standards
  - Documentation maintenance
  - Testing architecture patterns
  - Timezone management best practices

### Path-Specific Instructions (13 files)
See [instructions/README.md](instructions/README.md) for complete list:
- accessibility.instructions.md - WCAG AA/AAA compliance
- bootstrap.instructions.md - Bootstrap 5.3 & Font Awesome 6
- deployment.instructions.md - Dokku, Cloudflare, backups
- hotwire.instructions.md - Turbo + Stimulus patterns
- hotwire-native.instructions.md - Native mobile integration
- i18n-mobility.instructions.md - Internationalization
- importmaps.instructions.md - JavaScript modules
- notifications-noticed.instructions.md - Noticed gem
- rails-engine.instructions.md - Rails 7.1+ conventions
- search-elasticsearch.instructions.md - Elasticsearch 7
- security-encryption.instructions.md - Security practices
- sidekiq-redis.instructions.md - Background jobs
- view-helpers.instructions.md - Action View patterns

## How It Works

### For Copilot Chat
When you attach this repository to a Copilot conversation:
1. Repository-wide instructions from `copilot-instructions.md` are automatically included
2. Path-specific instructions are loaded based on the files you're working with
3. References to these instruction files appear in the chat response

### For Copilot Code Review
When reviewing pull requests:
1. Copilot loads instructions relevant to the modified files
2. Applies coding standards and best practices from instructions
3. Flags violations of documented patterns and conventions

### For Copilot Coding Agent
When working on issues:
1. Loads all relevant instruction files based on task
2. Follows test-driven development practices from AGENTS.md
3. Applies technology-specific patterns from path instructions
4. Validates changes against documented standards

## Maintaining Instructions

### When to Update
- Technology versions change (Rails, Ruby, dependencies)
- New architectural patterns are established
- Common issues/solutions are identified
- Testing practices evolve
- Security requirements change

### How to Update
1. **Repository-wide changes**: Edit `copilot-instructions.md`
2. **Command/workflow changes**: Edit `../AGENTS.md`
3. **Technology-specific changes**: Edit relevant file in `instructions/`
4. **New technologies**: Add new file to `instructions/` with frontmatter

### Update Checklist
- [ ] Keep instructions concise (copilot-instructions.md should stay under 2 pages conceptually)
- [ ] Include code examples for complex patterns
- [ ] Cross-reference related files
- [ ] Test that glob patterns match intended files
- [ ] Update this README if adding new instruction files
- [ ] Ensure no duplication between files

## Best Practices

### Writing Instructions
1. **Be specific**: Provide concrete examples, not just rules
2. **Be concise**: Copilot has context limits - prioritize essential information
3. **Be actionable**: Focus on what to do, not just what not to do
4. **Cross-reference**: Link to detailed documentation instead of duplicating
5. **Include common errors**: Document frequently encountered issues and solutions

### Organizing Instructions
1. **Repository-wide**: Architectural principles, core patterns that apply everywhere
2. **Agent-specific**: Commands, workflows, environment-specific details
3. **Path-specific**: Technology patterns that only apply to certain file types
4. **Avoid duplication**: Each concept should be documented in one primary location

### Testing Instructions
1. Ask Copilot to generate code and verify it follows the instructions
2. Check that glob patterns in frontmatter match intended files
3. Ensure instructions don't conflict with each other
4. Verify cross-references are accurate

## Resources

### Internal Documentation
- [docs/table_of_contents.md](../docs/table_of_contents.md) - Complete documentation index
- [docs/development/](../docs/development/) - Development guides
- [README.md](../README.md) - Project overview
- [CONTRIBUTING.md](../CONTRIBUTING.md) - Contribution guidelines

### GitHub Documentation
- [Custom Instructions Overview](https://docs.github.com/en/copilot/customizing-copilot/adding-custom-instructions-for-github-copilot)
- [Path-Specific Instructions](https://docs.github.com/en/copilot/customizing-copilot/adding-custom-instructions-for-github-copilot#creating-path-specific-custom-instructions)
- [Copilot Best Practices](https://docs.github.com/en/copilot/using-github-copilot/best-practices-for-using-github-copilot)

## Contributing

When contributing to instruction files:

1. **Test your changes**: Verify Copilot uses the instructions correctly
2. **Keep it maintainable**: Don't duplicate information
3. **Document patterns**: Include "why" not just "what"
4. **Update cross-references**: If you change file organization
5. **Get feedback**: Have others review for clarity

## Questions?

- **For technical issues**: See [AGENTS.md](../AGENTS.md) → Common Issues
- **For architecture questions**: See [copilot-instructions.md](copilot-instructions.md)
- **For contribution guidelines**: See [CONTRIBUTING.md](../CONTRIBUTING.md)
- **For general help**: See [docs/](../docs/)
