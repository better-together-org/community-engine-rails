# Technology-Specific Instructions

This directory contains path-specific instruction files for GitHub Copilot. Each file uses frontmatter to specify which files it applies to using glob patterns.

## How These Work

When Copilot is working on a file, it automatically loads instructions from files whose `applyTo` pattern matches the current file path. For example, when editing a Ruby file, Copilot will include instructions from `rails-engine.instructions.md`, `security-encryption.instructions.md`, etc.

## Available Instruction Files

### Accessibility
- **File**: `accessibility.instructions.md`
- **Applies to**: `**/*.erb`, `**/*.rb`, `**/*.js`, `**/*.scss`
- **Purpose**: WCAG AA/AAA compliance guidelines, semantic HTML, ARIA roles, keyboard navigation, color contrast requirements

### Frontend Framework
- **File**: `bootstrap.instructions.md`
- **Applies to**: `**/*.erb`, `**/*.scss`, `**/*.css`, `**/*.html.erb`
- **Purpose**: Bootstrap 5.3 styling, Font Awesome 6 icons, component patterns, responsive design

### Deployment
- **File**: `deployment.instructions.md`
- **Applies to**: `**/*.rb`, `**/*.yml`, `**/Procfile`, `**/*.sh`
- **Purpose**: Dokku deployment, Cloudflare configuration, backup strategies, environment management

### Hotwire (Turbo + Stimulus)
- **File**: `hotwire.instructions.md`
- **Applies to**: `**/*.js`, `**/*.erb`, `**/*.html.erb`
- **Purpose**: Turbo Drive/Frames/Streams, Stimulus controllers, progressive enhancement, event handling

### Hotwire Native
- **File**: `hotwire-native.instructions.md`
- **Applies to**: `**/*.rb`, `**/*.js`, `**/*.html.erb`
- **Purpose**: Native mobile integration, bridge components, path configuration, mobile optimization

### Internationalization
- **File**: `i18n-mobility.instructions.md`
- **Applies to**: `**/*.rb`, `**/*.yml`, `**/*.erb`
- **Purpose**: I18n key management, Mobility for attribute translations, locale handling, translation normalization

### Import Maps
- **File**: `importmaps.instructions.md`
- **Applies to**: `**/*.js`, `**/importmap.rb`
- **Purpose**: JavaScript module management without bundler, dependency pinning, ESM patterns

### Notifications
- **File**: `notifications-noticed.instructions.md`
- **Applies to**: `**/*.rb`
- **Purpose**: Noticed gem patterns, notification channels, delivery configuration, localization

### Rails Engine
- **File**: `rails-engine.instructions.md`
- **Applies to**: `**/*.rb`
- **Purpose**: Rails 7.1+ conventions, engine isolation, controllers, models, jobs, search, testing

### Search
- **File**: `search-elasticsearch.instructions.md`
- **Applies to**: `**/*.rb`
- **Purpose**: Elasticsearch 7 integration, indexing strategies, query patterns, cluster management

### Security & Encryption
- **File**: `security-encryption.instructions.md`
- **Applies to**: `**/*.rb`, `**/*.erb`, `**/*.js`
- **Purpose**: Active Record Encryption, CSP policies, input sanitization, secure storage, secret management

### Background Jobs
- **File**: `sidekiq-redis.instructions.md`
- **Applies to**: `**/*job.rb`, `**/sidekiq*.rb`, `**/redis*.rb`, `**/initializers/*.rb`
- **Purpose**: Sidekiq job patterns, Redis configuration, queue management, monitoring, caching

### View Helpers
- **File**: `view-helpers.instructions.md`
- **Applies to**: `**/*.erb`, `**/*.rb`, `**/helpers/*.rb`
- **Purpose**: Action View patterns, helper organization, I18n in views, formatting, navigation, forms, Hotwire integration

## Usage Guidelines

### For Developers
1. These files are automatically loaded by Copilot based on the files you're editing
2. You don't need to manually reference them in your prompts
3. If you need specific guidance, you can mention the technology (e.g., "follow Hotwire best practices")

### For Contributors
1. Keep instructions concise and actionable
2. Use frontmatter with accurate `applyTo` glob patterns
3. Include code examples for complex patterns
4. Reference other instruction files when relevant
5. Test patterns match the files they should apply to

### Adding New Instructions
1. Create a new `name.instructions.md` file in this directory
2. Add frontmatter with `applyTo` pattern:
   ```yaml
   ---
   applyTo: "**/*.rb,**/*.erb"
   ---
   ```
3. Write clear, concise instructions with examples
4. Update this README with a description of the new file
5. Test that the glob pattern matches intended files

## Related Files

- **[..copilot-instructions.md](../copilot-instructions.md)** - Repository-wide instructions, core principles, architecture patterns
- **[../../AGENTS.md](../../AGENTS.md)** - Detailed command reference, test workflows, debugging guidelines
- **[../../docs/](../../docs/)** - Comprehensive project documentation

## Testing Glob Patterns

To test if your glob pattern matches the intended files:

```bash
# In repository root
find . -path "./path/pattern" -type f | head -20

# Examples:
find . -name "*.erb" -type f | head -20
find . -path "**/helpers/*.rb" -type f | head -20
```

## Best Practices

1. **Single Responsibility**: Each instruction file should cover one technology or concern
2. **Clear Scope**: Use specific `applyTo` patterns that accurately match relevant files
3. **Avoid Duplication**: Reference other files instead of duplicating content
4. **Include Examples**: Show code patterns, not just rules
5. **Keep Updated**: Review and update when technology versions change
6. **Cross-Reference**: Link to main documentation for detailed guides
