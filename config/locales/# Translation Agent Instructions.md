# Translation Agent Instructions

Instructions for AI agents and automated contributors working on translations in the Better Together Community Engine.

## Project Context

- **Rails Engine**: Better Together Community Engine with host application pattern
- **Supported Locales**: en (source), es, fr, uk
- **Docker Environment**: All commands require `bin/dc-run` for database/service access
- **I18n Framework**: Rails i18n with i18n-tasks gem for management

## Core Translation Principles

### Technical Requirements
- **Preserve YAML structure exactly** - Any syntax error breaks the entire locale file
- **Maintain Rails i18n conventions** - Keep `%{variable}` interpolation intact
- **Never modify symbolic references** - Leave `:activerecord.models.user` unchanged
- **Respect locale hierarchy** - Follow Rails namespace conventions (`better_together.*`)

### Translation Strategy
1. **Security first**: Run `bin/dc-run bundle exec brakeman --quiet --no-pager` before translation work
2. **User-facing priority**: Translate authentication, navigation, forms, and error messages first
3. **Consistency over perfection**: Establish terminology early and maintain throughout
4. **Cultural appropriateness**: Research proper terms and formality levels for target culture

## Systematic Translation Process

### 1. Assessment Phase
```bash
# Check translation completeness
bin/dc-run i18n-tasks missing {locale}

# Find English strings in target locale files
grep -c "sign_in\|login\|register\|confirm" config/locales/{locale}.yml

# Identify high-impact untranslated sections
grep -n "better_together:\|devise:\|activerecord:" config/locales/{locale}.yml
```

### 2. Translation Phase

#### Priority Order:
1. **Devise Authentication** (`devise:`) - Complete login/registration flows
2. **ActiveRecord Models** (`activerecord:`) - Model attributes and relationships
3. **Better Together Core** (`better_together:`) - Main application features
4. **Navigation & UI** (`navbar:`, `navigation:`) - User interface elements
5. **Error Handling** (`errors:`, `flash:`) - User feedback messages
6. **Form Helpers** (`helpers:`, `hints:`) - Form labels and instructions

#### Translation Approach:
- **Work in logical chunks** - Complete related features together (e.g., all conversation features)
- **Use search patterns** to find remaining English strings systematically
- **Verify interpolation** - Ensure `%{platform_name}`, `%{user_name}` etc. are preserved
- **Check pluralization** - Handle `one:`, `other:` (and `few:`, `many:` for complex languages)

### 3. Quality Assurance
```bash
# Validate YAML syntax
bin/dc-run ruby -c config/locales/{locale}.yml

# Check translation health
bin/dc-run i18n-tasks health

# Normalize formatting
bin/dc-run i18n-tasks normalize
```

## Language-Specific Guidelines

### Ukrainian (uk)
- **Formality**: Use formal "Ви" form in interface
- **Technical terms**: Mix established Ukrainian IT terms with necessary anglicisms
- **Grammar**: Handle complex case system appropriately
- **Pluralization**: Use `one:`, `few:`, `many:`, `other:` forms per Ukrainian rules

**Key Terminology:**
```yaml
Platform: Платформа
Community: Спільнота  
Conversation: Розмова
User: Користувач
Person: Особа
Sign in: Увійти
Register: Зареєструватися
```

### Spanish (es)
- **Formality**: Use formal register appropriate for business/platform context
- **Gender**: Handle noun gender agreement correctly
- **Regional neutrality**: Avoid region-specific terms, use international Spanish
- **Technical terms**: Prefer Spanish equivalents where well-established

### French (fr)
- **Formality**: Use "vous" form, appropriate business French
- **Gender agreement**: Ensure proper masculine/feminine forms
- **Technical terminology**: Use established French tech terms over anglicisms
- **Cultural context**: Respect French linguistic preferences

## Rails Engine Translation Patterns

### ActiveRecord Attributes
```yaml
activerecord:
  attributes:
    better_together/model_name:
      field_name: Translated Field Name
      lock_version: Version de verrouillage  # Technical field
      created_at: Créé le                    # Timestamp
```

### Better Together Features
```yaml
better_together:
  conversations:
    index:
      title: Conversations               # Page title
      new: Nouvelle conversation         # Action button
    form:
      participants: Participants         # Form label
      message: Message                   # Form field
```

### Navigation Elements
```yaml
navbar:
  sign_in: Se connecter
  settings: Paramètres
  my_profile: Mon profil
navigation:
  header:
    events: Événements
    exchange_hub: Centre d'échange
```

## Validation and Testing

### Required Checks
- **YAML syntax validation** - File must parse without errors
- **Interpolation preservation** - All `%{variable}` placeholders intact
- **Key completeness** - No missing required translation keys
- **Pluralization correctness** - Proper plural forms for target language

### Testing Commands
```bash
# Test locale file loading
bin/dc-run rails runner "I18n.locale = :uk; I18n.t('devise.sessions.new.sign_in')"

# Check for missing translations
bin/dc-run i18n-tasks missing uk

# Verify application functionality
bin/dc-run bundle exec rspec spec/features/authentication_spec.rb
```

## Documentation Integration

### Required Documentation Updates
When completing translations for a new locale:

1. **Update README** with supported language information
2. **Document cultural considerations** for complex translation choices
3. **Add locale-specific user guides** if needed
4. **Update deployment docs** with locale configuration

### Translation Notes
Document complex translation decisions:

```yaml
# Example documentation in locale file comments
# Note: "Community" translated as "Спільнота" rather than "Громада" 
# to emphasize collaborative/social aspect over administrative division
better_together:
  community:
    name: Спільнота
```

## Error Prevention

### Common Pitfalls
1. **YAML formatting errors** - Always validate syntax after changes
2. **Missing interpolation variables** - Search and replace carefully
3. **Inconsistent terminology** - Maintain translation glossary
4. **Cultural inappropriate terms** - Research proper usage in target culture
5. **Incomplete translations** - Don't leave sections partially translated

### Prevention Strategies
- **Use search patterns** to systematically find English strings
- **Validate incrementally** - Check YAML syntax frequently during translation
- **Test in context** - Verify translations work in actual application usage
- **Maintain terminology list** - Keep consistent translations for repeated terms

## Integration with Better Together Standards

### Security Compliance
- Run Brakeman security scan before translation work
- Never introduce security vulnerabilities through translation changes
- Validate that translated user inputs follow same security patterns

### Testing Requirements
- All translation changes must maintain existing test coverage
- Add locale-specific tests for complex cultural adaptations
- Verify internationalized features work correctly in target locale

### Code Review Standards
- Include native speaker review when possible
- Document rationale for complex translation choices
- Ensure translations align with platform's tone and brand

## Automation Support

### Recommended Tools
```bash
# I18n management
bin/dc-run i18n-tasks add-missing     # Add missing keys
bin/dc-run i18n-tasks remove-unused  # Clean unused keys
bin/dc-run i18n-tasks translate-missing # Auto-translate with service

# Quality checks  
bin/dc-run i18n-tasks health         # Complete health check
bin/dc-run i18n-tasks check-consistent-interpolations
```

### CI/CD Integration
Translation work should integrate with existing CI pipelines:
- YAML syntax validation in PR checks
- Translation completeness verification
- Automated testing with new locale configurations

This guide ensures consistent, high-quality translations that maintain the technical integrity and user experience of the Better Together Community Engine across all supported languages.