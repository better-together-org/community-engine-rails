# Better Together I18n/Mobility Localization System

## Overview

The Better Together Community Engine implements a comprehensive internationalization (i18n) and localization system using **Rails I18n** for static content and the **Mobility gem** for dynamic model attributes. This system supports multiple locales with fallback mechanisms, AI-powered translation assistance, and a user-friendly tabbed interface for content editing.

## Architecture Components

### 1. Core Configuration

#### Available Locales
- **Primary Locales**: English (en), Spanish (es), French (fr)  
- **Default Locale**: English (en)
- **Configuration**: `config/application.rb`

```ruby
config.i18n.available_locales = %i[en es fr]
config.i18n.default_locale = :en
```

#### Route Configuration
- **Locale URL Prefix**: `/:locale/` (e.g., `/en/pages`, `/es/páginas`, `/fr/pages`)
- **Pattern Matching**: Dynamically generates route constraints based on available locales
- **Fallback**: Redirects to default locale when no locale specified

### 2. Mobility Gem Integration

The system uses the **Mobility gem** to handle model attribute translations with multiple backend strategies:

#### Backend Configuration (`config/initializers/mobility.rb`)
- **Default Backend**: Key-Value with text type
- **Active Plugins**: 
  - Reader/Writer accessors
  - Backend reader (`attribute_backend`)
  - Query support (`.i18n` scope)
  - Caching layer
  - Fallback support
  - Presence validation (converts blank to nil)
  - Locale-specific accessors (`attribute_en`, `attribute_es`, etc.)

#### Translation Backends

**1. Key-Value Backend (String/Text)**
- **Purpose**: Simple text attributes (names, titles, descriptions)
- **Storage**: `mobility_string_translations` and `mobility_text_translations` tables
- **Implementation**: `Mobility::Backends::ActiveRecord::KeyValue`

**2. Action Text Backend (Rich Content)**
- **Purpose**: Rich text content with formatting, attachments, embeds
- **Storage**: `action_text_rich_texts` table with mobility integration
- **Implementation**: `Mobility::Backends::ActionText`

### 3. Translatable Models

#### Common Model Pattern
Models include the `BetterTogether::Translatable` concern and define translated attributes:

```ruby
class Page < ApplicationRecord
  include BetterTogether::Translatable
  
  translates :title, type: :string          # Key-Value backend
  translates :content, backend: :action_text # Action Text backend
end
```

#### Key Translatable Models
- **Pages**: `title` (string), `content` (rich text)
- **Posts**: `title` (string), `content` (rich text)  
- **Navigation Items**: `title` (string)
- **Categories**: `name` (string), `description` (rich text)
- **Content Blocks**: Various attributes based on block type
- **Uploads**: `name` (string), `description` (rich text)

### 4. Translation UI System

#### Tabbed Interface Components

**Form Helpers**
- `_translated_string_field.html.erb`: Single-line text inputs per locale
- `_translated_text_field.html.erb`: Multi-line text areas per locale  
- `_translated_rich_text_field.html.erb`: Rich text editors (Trix) per locale

**JavaScript Controller** (`translation_controller.js`)
- **Functionality**: 
  - Tab synchronization across field groups
  - Translation status indicators (✓ present, ⚠ missing)
  - AI translation integration
  - Real-time validation feedback

**Helper Methods** (`translatable_fields_helper.rb`)
- **Tab Generation**: Creates locale tabs with status indicators
- **AI Integration**: Dropdown menus for translation options
- **Accessibility**: ARIA labels and screen reader support

#### Visual Indicators
- **Green Check (✓)**: Translation present and saved
- **Yellow Warning (⚠)**: No translation available
- **Tab Highlighting**: Active locale visually emphasized
- **Error States**: Validation errors shown per locale

### 5. AI Translation System

#### TranslationBot (`app/robots/better_together/translation_bot.rb`)
- **Provider**: OpenAI GPT integration
- **Features**:
  - Content preprocessing (Trix attachment handling)
  - Context-aware translation prompts
  - Cost estimation and usage tracking
  - Error handling and fallback mechanisms

#### Translation Workflow
1. **User Trigger**: Click "AI Translate from [Locale]" dropdown option
2. **AJAX Request**: Send content to `TranslationsController#translate`
3. **Processing**: Extract content, handle rich text attachments
4. **API Call**: Submit to OpenAI with translation prompt
5. **Response**: Process and restore attachments in translated content
6. **UI Update**: Populate target locale field with translation
7. **Validation**: Real-time indicator updates

#### Bulk Translation Tasks
**Rake Tasks** (`lib/tasks/ai_translations.rake`)
- `better_together:ai_translations:from_en:page_attrs`
- `better_together:ai_translations:from_en:nav_item_attrs`
- `better_together:ai_translations:from_en:hero_rich_text`

### 6. Fallback Mechanisms

#### I18n Fallbacks (Static Content)
1. **Requested Locale**: `t('key', locale: :es)`
2. **Fallback Chain**: Spanish → English → Key name
3. **Missing Keys**: i18n-tasks gem identifies gaps

#### Mobility Fallbacks (Model Attributes)
1. **Current Locale**: Check `attribute_es`
2. **English Fallback**: Check `attribute_en` 
3. **First Available**: Scan all locales for first present value
4. **Nil Result**: Return nil if no translations exist

### 7. Database Schema

#### Translation Storage Tables

**Mobility String Translations**
```sql
CREATE TABLE mobility_string_translations (
  id bigint PRIMARY KEY,
  locale varchar(255) NOT NULL,
  key varchar(255) NOT NULL,
  value text,
  translatable_type varchar(255),
  translatable_id bigint,
  created_at timestamp,
  updated_at timestamp
);
```

**Mobility Text Translations** (similar structure with longer value field)

**Action Text Rich Texts** (enhanced with locale support)
```sql
CREATE TABLE action_text_rich_texts (
  id bigint PRIMARY KEY,
  name varchar(255) NOT NULL,
  body text,
  record_type varchar(255),
  record_id bigint,
  locale varchar(255),
  created_at timestamp,
  updated_at timestamp
);
```

**FriendlyId Slugs** (locale-aware URL slugs)
```sql
CREATE TABLE friendly_id_slugs (
  id bigint PRIMARY KEY,
  slug varchar(255) NOT NULL,
  sluggable_id bigint,
  sluggable_type varchar(255),
  scope varchar(255),
  locale varchar(255) NOT NULL,
  created_at timestamp
);
```

### 8. Frontend Locale Management

#### Locale Switcher UI
- **Location**: Navigation bar dropdown
- **Display**: Language flag icon + locale code (EN, ES, FR)
- **Functionality**: Preserves current page/context when switching
- **Accessibility**: Tooltips and screen reader support

#### URL Structure
- **Format**: `/:locale/path/to/resource`
- **Examples**: 
  - `/en/pages/about-us`
  - `/es/páginas/acerca-de-nosotros`  
  - `/fr/pages/à-propos-de-nous`

### 9. Content Management Workflow

#### Creating Multilingual Content
1. **Form Rendering**: Generate tabbed interface for all locales
2. **Content Entry**: Users fill in translations per locale tab
3. **Validation**: Check presence requirements per locale
4. **Storage**: Save to appropriate Mobility backend
5. **Publishing**: Content available immediately in respective locales

#### Translation Status Tracking
- **Per-Field Indicators**: Visual cues show translation completeness
- **Bulk Status**: Admin dashboards show translation coverage
- **Automated Tasks**: Scheduled translation jobs for batch processing

### 10. Performance Optimizations

#### Caching Strategy
- **Mobility Cache**: Enabled for translated attribute reads
- **I18n Caching**: Rails built-in translation caching
- **Query Optimization**: `.with_translations` scope for efficient loading

#### Database Indexing
- **Composite Indexes**: `(translatable_type, translatable_id, locale, key)`
- **Locale Indexes**: Fast locale-specific queries
- **Slug Indexes**: Efficient friendly URL resolution

### 11. Validation and Quality Assurance

#### Translation Validation Tools
- **i18n-tasks gem**: Detects missing keys, unused translations
- **Presence Validators**: Ensures required translations exist
- **Custom Validators**: Business logic for translation completeness

#### Quality Assurance Commands
```bash
# Check translation health
i18n-tasks health

# Find missing translations  
i18n-tasks missing

# Add missing keys (English first)
i18n-tasks add-missing

# Normalize translation files
i18n-tasks normalize
```

### 12. Development Guidelines

#### Adding New Translatable Content
1. **Model Changes**: Add `translates :attribute` declarations
2. **Migration**: Generate Mobility migration if needed
3. **Forms**: Use translation field partials
4. **Validations**: Add presence validators for required locales
5. **Tests**: Include translation scenarios in specs

#### Best Practices
- **English First**: Always create English content before translating
- **Consistent Keys**: Use namespaced, descriptive translation keys
- **Fallback Awareness**: Design UI to handle missing translations gracefully  
- **Performance**: Use `.with_translations` scope for bulk loading
- **Accessibility**: Include proper ARIA labels and language attributes

## Process Flow Summary

The localization system operates through several interconnected workflows:

1. **Request Processing**: Locale detection from URL → I18n.locale setting → Route processing
2. **Content Retrieval**: Translation key lookup → Backend queries → Fallback resolution → Content delivery
3. **Content Creation**: Tabbed UI rendering → Multi-locale input → Validation → Mobility storage
4. **AI Translation**: User trigger → API processing → Content transformation → Field updates
5. **Quality Assurance**: Bulk validation → Missing key detection → Translation normalization

This comprehensive system ensures that Better Together applications can deliver fully localized experiences while maintaining content quality and providing powerful tools for content creators and translators.
