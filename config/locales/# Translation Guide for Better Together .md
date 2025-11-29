# Translation Guide for Better Together Community Engine

This guide provides instructions for translating locale files in the Better Together Community Engine Rails application.

## Overview

The Better Together Community Engine supports multiple locales with comprehensive internationalization (i18n) coverage. All user-facing strings must be translatable, and translations should maintain consistency across features while respecting cultural and linguistic nuances.

## Supported Locales

- **English (en)**: Primary/source locale
- **Spanish (es)**: Full translation support
- **French (fr)**: Full translation support  
- **Ukrainian (uk)**: Full translation support

## File Structure

Locale files are organized in `config/locales/` with the naming pattern `{locale}.yml`:

```
config/locales/
├── en.yml          # English (source)
├── es.yml          # Spanish
├── fr.yml          # French
└── uk.yml          # Ukrainian
```

## Translation Principles

### 1. Technical YAML Requirements

- **Preserve YAML syntax exactly** - Any syntax errors break the entire file
- **Maintain proper indentation** - YAML is whitespace-sensitive
- **Keep symbolic references intact** - Values like `:activerecord.models.user` should remain unchanged
- **Preserve Rails i18n interpolation** - Keep `%{variable_name}` placeholders exactly as-is
- **Never modify the root locale key** - `en:` becomes `uk:`, `es:`, `fr:` etc.

### 2. Translation Strategy & Priorities

#### **High Priority (User-Facing)**
1. **Authentication & Registration** - Devise flows, login, signup, password recovery
2. **Navigation & UI** - Menus, buttons, labels, breadcrumbs
3. **Core Features** - Conversations, events, communities, profiles
4. **Error Messages** - Validation errors, flash messages, user feedback
5. **Form Elements** - Field labels, hints, placeholders, submit buttons

#### **Medium Priority (Administrative)**
1. **Content Management** - Page editing, block management
2. **Platform Administration** - User management, settings, invitations
3. **Reporting & Analytics** - Metrics, reports, administrative views
4. **Advanced Features** - Joatu marketplace, complex workflows

#### **Lower Priority (Technical)**
1. **Developer-facing content** - Internal system messages
2. **Advanced administrative features** - Complex configuration options
3. **Specialized workflows** - Edge cases and rarely-used features

### 3. Consistency Standards

#### **Terminology Consistency**
Establish key terms early and use consistently throughout:

```yaml
# Example: Ukrainian terminology
Community: Спільнота          # Not варying between terms
Platform: Платформа           # Consistent across all contexts  
Conversation: Розмова         # Standard throughout
User: Користувач              # Never mixing with alternatives
Person: Особа                 # Distinct from User
```

#### **Technical Accuracy**
- **Maintain technical meaning** while making language natural
- **Use established technical terms** where they exist in the target language
- **Create consistent new terms** for platform-specific concepts
- **Preserve relationships** between related concepts

### 4. Rails Engine Specific Considerations

#### **Namespace Awareness**
- Better Together engine uses `better_together.*` keys
- ActiveRecord models follow `better_together/model_name` pattern
- Maintain proper hierarchical structure in translations

#### **Model Relationships**
- Understand how ActiveRecord attributes relate to user experience
- Translate field names that appear in forms and views
- Maintain consistency between model attributes and UI labels

#### **Pluralization Rules**
Different languages have complex plural forms that Rails handles:

```yaml
# Ukrainian pluralization example
datetime:
  distance_in_words:
    x_hours:
      one: година
      few: години  
      other: годин
```

### 5. Quality Assurance Process

#### **Systematic Approach**
1. **Complete related sections together** - Don't leave partial translations
2. **Verify technical functionality** - Ensure translated strings work in context
3. **Check interpolation variables** - Verify `%{variable}` placeholders are preserved
4. **Test pluralization** - Confirm plural forms work correctly

#### **Grammar and Localization**
- **Proper target language grammar** including cases, gender agreement, verb aspects
- **Cultural appropriateness** - Terms that make sense in cultural context
- **Consistent formality level** - Choose appropriate formal/informal tone
- **Technical terminology** - Use established tech terms where available

## Translation Workflow

### 1. Preparation Phase
```bash
# Run security scan before making changes
bin/dc-run bundle exec brakeman --quiet --no-pager

# Check for existing English strings needing translation
bin/dc-run i18n-tasks missing
```

### 2. Translation Phase
```bash
# Normalize existing translations
bin/dc-run i18n-tasks normalize

# Identify untranslated strings using search patterns
grep -n "acceptance" config/locales/uk.yml
grep -n "confirm" config/locales/uk.yml  
```

### 3. Validation Phase
```bash
# Check translation health
bin/dc-run i18n-tasks health

# Verify YAML syntax
bin/dc-run ruby -c config/locales/uk.yml

# Run application tests with new locale
bin/dc-run bundle exec rspec
```

## Language-Specific Guidelines

### Ukrainian (uk)
- **Grammar**: Complex case system, aspect-based verbs, flexible word order
- **Formality**: Use formal "Ви" in UI, appropriate business language
- **Technical Terms**: Mix of Ukrainian terms and accepted anglicisms
- **Pluralization**: Uses `one:`, `few:`, `many:`, `other:` forms

### Spanish (es)  
- **Grammar**: Gendered nouns, formal/informal address (tú/usted)
- **Formality**: Generally formal in platform context
- **Regional Considerations**: Use neutral Spanish avoiding regional-specific terms
- **Pluralization**: Standard `one:` and `other:` forms

### French (fr)
- **Grammar**: Gendered nouns, formal address (vous), agreement rules
- **Formality**: Formal tone appropriate for platform use
- **Technical Terms**: Prefer French terms over anglicisms where established
- **Pluralization**: Standard `one:` and `other:` forms

## Common Patterns

### ActiveRecord Attributes
```yaml
activerecord:
  attributes:
    better_together/person:
      name: Ім'я                    # Field label
      description: Опис             # Field label  
      slug: Слаг                    # Technical term
      lock_version: Версія блокування # Technical field
```

### Navigation Elements
```yaml
better_together:
  navbar:
    my_profile: Мій профіль
    settings: Налаштування
    sign_in: Увійти
    log_out: Вийти
```

### Form Elements
```yaml
helpers:
  hint:
    person:
      name: Введіть повне ім'я особи.
      description: Надайте короткий опис або біографію.
  submit:
    create: Створити %{model}
    update: Оновити %{model}
```

## Error Prevention

### Common Mistakes to Avoid
1. **Breaking YAML syntax** - Always validate syntax after changes
2. **Missing interpolation variables** - Ensure `%{var}` placeholders are preserved
3. **Inconsistent terminology** - Use established translations for repeated concepts
4. **Cultural insensitivity** - Research appropriate terms for target culture
5. **Technical inaccuracy** - Maintain technical meaning in translations

### Validation Commands
```bash
# Check YAML syntax
ruby -e "require 'yaml'; YAML.load_file('config/locales/uk.yml')"

# Find missing translations
i18n-tasks missing uk

# Check for unused keys
i18n-tasks unused

# Normalize formatting
i18n-tasks normalize
```

## Integration with Documentation

When translating new features:
1. **Update system documentation** to reflect multilingual support
2. **Add translation notes** for complex or context-dependent terms
3. **Document cultural considerations** that affect translation choices
4. **Update user guides** for new locales

## Maintenance

### Regular Tasks
- **Review and update** translations when English source changes
- **Check consistency** across related features and sections
- **Update documentation** when translation patterns change
- **Test application** functionality in all supported locales

### Quality Control
- **Peer review** translations with native speakers when possible
- **User testing** in target languages to verify usability
- **Regular audits** of translation completeness and consistency
- **Performance monitoring** to ensure translated content loads correctly

This guide should be updated as new patterns emerge and additional languages are supported.