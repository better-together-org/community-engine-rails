# AI Integration System Documentation

## Overview

The Better Together Community Engine includes a comprehensive AI integration system primarily focused on automated content translation using OpenAI's GPT models. The system provides both real-time translation capabilities through the user interface and batch processing tools for large-scale content localization.

## Process Flow Diagram

```mermaid
graph TB
    %% AI System Configuration
    subgraph "AI System Configuration"
        A[Environment Setup] --> B{OPENAI_ACCESS_TOKEN Set?}
        B -->|Yes| C[Initialize OpenAI Client]
        B -->|No| D[Disable AI Features]
        C --> E[Configure GPT Model]
        E --> F[AI Features Available]
    end

    %% Real-time Translation Flow
    subgraph "Real-time Translation Process"
        G[User Clicks AI Translate] --> H[JavaScript Controller Activated]
        H --> I[Extract Source Content]
        I --> J{Content Type?}
        J -->|Rich Text| K[Process Trix Attachments]
        J -->|Plain Text| L[Direct Content Extraction]
        K --> M[Replace Attachments with Placeholders]
        L --> N[AJAX Request to TranslationsController]
        M --> N
        N --> O[TranslationBot.translate()]
    end

    %% Translation Bot Processing
    subgraph "TranslationBot Processing"
        P[Receive Translation Request] --> Q[Pre-process Content]
        Q --> R[Extract Trix Attachments]
        R --> S[Create Placeholder Map]
        S --> T[OpenAI API Call]
        T --> U[Process GPT Response]
        U --> V[Restore Attachments]
        V --> W[Calculate Token Usage]
        W --> X[Estimate Cost]
    end

    %% Logging and Tracking
    subgraph "AI Usage Logging"
        Y[TranslationLoggerJob] --> Z[Create Log Record]
        Z --> AA[Track Token Usage]
        AA --> BB[Record Costs]
        BB --> CC[Store Request/Response]
        CC --> DD[Performance Metrics]
    end

    %% Bulk Translation System
    subgraph "Bulk Translation Tasks"
        EE[Rake Task Execution] --> FF[Select Content Models]
        FF --> GG[Iterate Through Records]
        GG --> HH{Translation Exists?}
        HH -->|No| II[AI Translate Content]
        HH -->|Yes| JJ[Skip Record]
        II --> KK[Save Translation]
        KK --> LL[Update Progress Counter]
        JJ --> LL
        LL --> MM{More Records?}
        MM -->|Yes| GG
        MM -->|No| NN[Task Complete]
    end

    %% UI Integration
    subgraph "User Interface Integration"
        OO[Form Field Rendering] --> PP{AI Enabled?}
        PP -->|Yes| QQ[Show AI Translate Dropdown]
        PP -->|No| RR[Basic Language Tabs]
        QQ --> SS[Language Selection Options]
        SS --> TT[Real-time Status Indicators]
        TT --> UU[Translation Success/Error Feedback]
    end

    %% Error Handling
    subgraph "Error Handling & Fallbacks"
        VV[API Request Failure] --> WW[Log Error Details]
        WW --> XX[Return Error Response]
        XX --> YY[Display User-Friendly Message]
        YY --> ZZ[Maintain Form Functionality]
    end

    %% Connect main flows
    F --> G
    O --> P
    X --> Y
    P --> T
    T --> O
    EE --> II
    II --> P
    OO --> G

    %% Styling
    classDef configBox fill:#e3f2fd,stroke:#1976d2,stroke-width:2px
    classDef realtimeBox fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
    classDef botBox fill:#e8f5e8,stroke:#388e3c,stroke-width:2px
    classDef loggingBox fill:#fff3e0,stroke:#f57c00,stroke-width:2px
    classDef bulkBox fill:#fce4ec,stroke:#c2185b,stroke-width:2px
    classDef uiBox fill:#f1f8e9,stroke:#689f38,stroke-width:2px
    classDef errorBox fill:#ffebee,stroke:#d32f2f,stroke-width:2px
    classDef decisionBox fill:#fff8e1,stroke:#ffa000,stroke-width:2px

    class A,C,E,F configBox
    class G,H,I,L,N realtimeBox
    class P,Q,R,S,T,U,V,W,X botBox
    class Y,Z,AA,BB,CC,DD loggingBox
    class EE,FF,GG,II,JJ,KK,LL,NN bulkBox
    class OO,QQ,RR,SS,TT,UU uiBox
    class VV,WW,XX,YY,ZZ errorBox
    class B,J,HH,PP,MM decisionBox
```

**Diagram Files:**
- 📊 [Mermaid Source](../diagrams/source/ai_integration_system_flow.mmd) - Editable source
- 🖼️ [PNG Export](../diagrams/exports/png/ai_integration_system_flow.png) - High-resolution image
- 🎯 [SVG Export](../diagrams/exports/svg/ai_integration_system_flow.svg) - Vector graphics

### Process Flow Explanation

The AI integration system operates through several interconnected processes:

**System Configuration**: Automatic detection and setup of OpenAI integration based on environment variables.

**Real-time Translation**: User-initiated translations through the web interface with immediate feedback.

**Bot Processing**: Sophisticated content processing with attachment handling and cost tracking.

**Usage Logging**: Comprehensive tracking of all AI interactions for cost management and analytics.

**Bulk Processing**: Automated translation of large content sets through rake tasks.

**UI Integration**: Seamless integration with form fields and translation status indicators.

## System Architecture

### Core Components

#### 1. ApplicationBot (`app/robots/better_together/application_bot.rb`)

**Purpose**: Base class for all AI-powered bots providing shared OpenAI client configuration.

**Key Features**:
- Automatic OpenAI client initialization
- Configurable model selection (defaults to GPT-4O-mini)
- Environment variable validation
- Error handling for missing credentials

**Configuration**:
```ruby
# Default model: 'gpt-4o-mini-2024-07-18'
bot = ApplicationBot.new(model: 'gpt-3.5-turbo')
```

#### 2. TranslationBot (`app/robots/better_together/translation_bot.rb`)

**Purpose**: Specialized bot for content translation with advanced preprocessing capabilities.

**Key Features**:
- **Trix Attachment Processing**: Preserves rich text editor attachments during translation
- **Token Counting**: Accurate cost estimation using OpenAI's token counting
- **Usage Logging**: Automatic logging of all translation requests
- **Multi-locale Support**: Handles translation between any supported locale pair
- **Content Preprocessing**: Intelligent handling of HTML and rich text content

**Translation Workflow**:
1. **Content Extraction**: Extract source content from various field types
2. **Attachment Processing**: Replace Trix attachments with placeholders
3. **API Communication**: Submit processed content to OpenAI
4. **Response Processing**: Parse and validate translation response
5. **Restoration**: Replace placeholders with original attachments
6. **Cost Calculation**: Estimate usage costs based on token consumption
7. **Logging**: Record transaction details for analytics

#### 3. AI Logging System

##### Translation Log Model (`app/models/better_together/ai/log/translation.rb`)
**Purpose**: Comprehensive tracking of all AI translation activities.

**Database Schema**:
```ruby
# better_together_ai_log_translations table
t.text :request            # Original content sent to AI
t.text :response           # Translated content received
t.string :model           # AI model used (indexed)
t.integer :prompt_tokens  # Input token count
t.integer :completion_tokens # Output token count  
t.integer :tokens_used    # Total tokens consumed
t.decimal :estimated_cost # Calculated cost ($)
t.datetime :start_time    # Request timestamp
t.datetime :end_time      # Response timestamp
t.string :status          # success/failure/pending (indexed)
t.references :initiator   # Person who requested translation
t.string :source_locale   # Source language (indexed)
t.string :target_locale   # Target language (indexed)
```

##### Translation Logger Job (`app/jobs/better_together/ai/log/translation_logger_job.rb`)
**Purpose**: Asynchronous logging of translation activities to prevent blocking.

**Features**:
- Background job processing
- Comprehensive metric tracking
- Cost calculation and storage
- Performance timing analysis

#### 4. Web Interface Integration

##### TranslationsController (`app/controllers/better_together/translations_controller.rb`)
**Purpose**: HTTP endpoint for real-time translation requests.

**API Endpoint**:
```
POST /translations/translate
```

**Request Parameters**:
- `content`: Text/HTML content to translate
- `source_locale`: Source language code
- `target_locale`: Target language code

**Response Format**:
```json
{
  "translation": "Translated content...",
  "error": "Error message if failed"
}
```

##### JavaScript Translation Controller (`app/javascript/controllers/better_together/translation_controller.js`)
**Purpose**: Stimulus controller managing client-side translation interactions.

**Key Features**:
- **Multi-field Support**: Handles text inputs, textareas, and Trix editors
- **Real-time Status**: Dynamic translation indicators
- **Loading States**: Visual feedback during API requests
- **Error Handling**: Graceful degradation on failures
- **Content Synchronization**: Maintains state across language tabs

**User Interaction Flow**:
1. User clicks "AI Translate from [Language]" dropdown option
2. JavaScript extracts content from source locale field
3. Loading indicator displayed (spinning language icon)
4. AJAX request sent to TranslationsController
5. Response processed and target field populated
6. Translation status indicator updated
7. Loading state removed

#### 5. UI Helper System

##### TranslatableFieldsHelper (`app/helpers/better_together/translatable_fields_helper.rb`)
**Purpose**: Renders AI-enabled translation interface components.

**Components**:
- **Language Tab Buttons**: Navigation between locales with status indicators
- **AI Translation Dropdown**: Contextual translation options (only when API key present)
- **Status Indicators**: Visual feedback for translation completeness
- **Responsive Layout**: Bootstrap-integrated design

**Conditional Rendering**:
```ruby
# AI features only shown when OpenAI is configured
if ENV['OPENAI_ACCESS_TOKEN']
  render_translation_dropdown(locale, unique_locale_attribute, attribute, base_url, translation_present)
end
```

### Bulk Translation System

#### Rake Tasks (`lib/tasks/ai_translations.rake`)
**Purpose**: Automated translation of existing content at scale.

**Available Tasks**:
```bash
# Translate page attributes
rake better_together:ai_translations:from_en:page_attrs

# Translate rich text block content
rake better_together:ai_translations:from_en:rich_text_block_attrs

# Translate hero block content
rake better_together:ai_translations:from_en:hero_block_attrs

# Translate navigation items
rake better_together:ai_translations:from_en:nav_item_attrs
```

**Processing Logic**:
1. **Scope Selection**: Query records needing translation
2. **Content Analysis**: Identify translateable attributes
3. **Gap Detection**: Skip existing translations
4. **Batch Processing**: Translate missing content
5. **Progress Tracking**: Count and report completed translations

## Configuration

### Environment Variables

#### Required Configuration
```bash
# OpenAI API access token (required for AI features)
OPENAI_ACCESS_TOKEN=sk-...your-api-key
```

#### Optional Configuration
```bash
# Model selection (defaults to gpt-4o-mini-2024-07-18)
OPENAI_MODEL=gpt-3.5-turbo

# API endpoint customization (uses OpenAI default)
OPENAI_BASE_URL=https://api.openai.com/v1
```

### OpenAI Client Configuration (`config/initializers/openai.rb`)
```ruby
if ENV['OPENAI_ACCESS_TOKEN']
  OpenAI.configure do |config|
    config.access_token = ENV.fetch('OPENAI_ACCESS_TOKEN')
    config.log_errors = Rails.env.development?
  end
end
```

### Dependency Management
The system uses the `ruby-openai` gem for API integration:

```ruby
# better_together.gemspec
spec.add_dependency 'ruby-openai'
```

## Cost Management

### Token Usage Tracking
The system provides comprehensive cost tracking:

**Cost Calculation Model**:
```ruby
# Per-token pricing (as of 2024)
RATES = {
  'gpt-4o-mini-2024-07-18' => {
    prompt: 0.03 / 1000,      # $0.03 per 1K prompt tokens
    completion: 0.06 / 1000   # $0.06 per 1K completion tokens
  },
  'gpt-3.5-turbo' => {
    prompt: 0.02 / 1000,      # $0.02 per 1K prompt tokens  
    completion: 0.02 / 1000   # $0.02 per 1K completion tokens
  }
}
```

### Usage Analytics
Query translation logs for cost analysis:

```ruby
# Total cost over time period
BetterTogether::Ai::Log::Translation
  .where(created_at: 1.month.ago..Time.current)
  .sum(:estimated_cost)

# Usage by user
BetterTogether::Ai::Log::Translation
  .joins(:initiator)
  .group('better_together_people.name')
  .sum(:estimated_cost)

# Token consumption by model
BetterTogether::Ai::Log::Translation
  .group(:model)
  .sum(:tokens_used)
```

## Security Considerations

### API Key Management
- **Environment Variables**: Store OpenAI API key securely
- **Access Control**: Limit translation features to authenticated users
- **Rate Limiting**: Consider implementing rate limits for API calls
- **Error Handling**: Prevent API key exposure in error messages

### Content Security
- **Input Validation**: Sanitize content before sending to AI
- **Output Processing**: Validate AI responses before display
- **Attachment Preservation**: Secure handling of file attachments
- **Logging Privacy**: Consider PII implications in translation logs

### User Authorization
```ruby
# Only logged-in users have access to AI translation
authenticated :user do
  post 'translations/translate', to: 'translations#translate', as: :ai_translate
end
```

## Error Handling

### Common Error Scenarios
1. **Missing API Key**: Graceful feature disabling
2. **API Rate Limits**: Retry logic with exponential backoff
3. **Network Failures**: User-friendly error messages
4. **Invalid Content**: Content validation and sanitization
5. **Token Limits**: Request truncation or chunking

### Error Response Format
```json
{
  "error": "Translation failed: Rate limit exceeded",
  "code": "rate_limit_exceeded",
  "retry_after": 60
}
```

### Fallback Strategies
- **Manual Translation**: Always available as fallback
- **Cached Translations**: Reuse previous translations where possible
- **Progressive Enhancement**: Core functionality works without AI

## Performance Optimization

### Caching Strategy
- **Translation Cache**: Store AI translations to avoid duplicate requests
- **Token Estimation**: Cache token counts for repeated content
- **Response Caching**: Cache successful translations temporarily

### Batch Processing Optimization
- **Concurrency Control**: Limit simultaneous API requests
- **Progress Tracking**: Provide feedback on long-running tasks  
- **Incremental Processing**: Resume interrupted batch jobs
- **Resource Management**: Monitor memory usage during bulk operations

### Client-side Performance
- **Lazy Loading**: Load AI features only when needed
- **Debouncing**: Prevent duplicate translation requests
- **Progressive Enhancement**: Core functionality independent of AI
- **Loading States**: Provide immediate user feedback

## Testing Strategy

### Unit Tests
- **Bot Functionality**: TranslationBot core methods
- **Cost Calculation**: Token counting and cost estimation
- **Content Processing**: Attachment handling and restoration
- **Error Handling**: Various failure scenarios

### Integration Tests
- **API Communication**: OpenAI service integration
- **Logging System**: Translation log creation and retrieval
- **Controller Actions**: HTTP endpoint functionality
- **Background Jobs**: Asynchronous logging behavior

### Feature Tests
- **UI Interactions**: JavaScript translation workflow
- **Form Integration**: Multi-locale form handling
- **Bulk Operations**: Rake task execution
- **Error Scenarios**: Graceful degradation testing

### Test Configuration
```ruby
# Test environment setup
ENV['OPENAI_ACCESS_TOKEN'] = 'test_key'

# Mock API responses for testing
WebMock.stub_request(:post, /api\.openai\.com/)
  .to_return(status: 200, body: mock_translation_response)
```

## Monitoring and Analytics

### Key Metrics
- **Translation Volume**: Daily/monthly translation count
- **Cost Tracking**: Cumulative AI service costs
- **Success Rates**: Translation success vs failure rates
- **Performance Metrics**: Average response times
- **User Adoption**: Active users of AI features

### Logging Configuration
```ruby
# Development: Detailed logging enabled
config.log_errors = Rails.env.development?

# Production: Error logging only
config.log_errors = false
```

### Alert Thresholds
- **Cost Alerts**: Daily/monthly spending limits
- **Error Rate Alerts**: High failure rate notifications
- **Performance Alerts**: Slow response time warnings
- **Token Usage Alerts**: Approaching rate limits

## Future Enhancements

### Planned Features
- **Multiple AI Providers**: Support for Google Translate, DeepL, etc.
- **Translation Memory**: Leverage previous translations for consistency
- **Batch Translation UI**: Web interface for bulk operations
- **Quality Scoring**: AI translation quality assessment
- **Custom Prompts**: Domain-specific translation instructions
- **Translation Review**: Human review workflow for critical content

### Technical Improvements
- **Streaming Responses**: Real-time translation updates
- **Offline Capabilities**: Local translation models
- **Advanced Caching**: Intelligent translation reuse
- **API Rate Management**: Dynamic rate limiting
- **Enhanced Security**: Translation audit trails
- **Performance Optimization**: Parallel processing capabilities

### Integration Opportunities
- **Content Workflow**: Integration with approval processes
- **SEO Optimization**: Automated meta-tag translation
- **Email Campaigns**: Multilingual email content
- **API Exposure**: External translation API endpoints
- **Mobile App**: Native mobile translation features
- **Voice Translation**: Speech-to-text translation capabilities

## Troubleshooting

### Common Issues

#### 1. AI Features Not Visible
**Symptoms**: No AI translate dropdown appears
**Solution**: Verify `OPENAI_ACCESS_TOKEN` environment variable is set

#### 2. Translation Requests Failing
**Symptoms**: API errors in logs, empty translation responses
**Diagnosis**: Check API key validity, rate limits, network connectivity
**Solution**: Validate credentials, implement retry logic

#### 3. High Translation Costs
**Symptoms**: Unexpected API charges
**Diagnosis**: Review translation logs for usage patterns
**Solution**: Implement cost controls, user rate limiting

#### 4. Slow Translation Response
**Symptoms**: Long delays before translation appears
**Diagnosis**: Check network latency, API response times
**Solution**: Implement timeout handling, progress indicators

#### 5. Content Corruption
**Symptoms**: Rich text formatting lost after translation
**Diagnosis**: Trix attachment processing issues
**Solution**: Review attachment placeholder logic

### Debug Commands
```ruby
# Check AI system configuration
BetterTogether::ApplicationBot.new.client.inspect

# Review recent translation activity
BetterTogether::Ai::Log::Translation.recent.limit(10)

# Calculate total usage costs
BetterTogether::Ai::Log::Translation.sum(:estimated_cost)

# Test translation functionality
bot = BetterTogether::TranslationBot.new
bot.translate("Hello world", target_locale: 'es', source_locale: 'en')

# Check bulk translation status
BetterTogether::Page.joins(:string_translations)
  .where(string_translations: { locale: 'es' })
  .count
```

This comprehensive AI integration system provides powerful automated translation capabilities while maintaining cost control, security, and user experience standards. The modular architecture allows for easy extension and customization based on specific deployment needs.
