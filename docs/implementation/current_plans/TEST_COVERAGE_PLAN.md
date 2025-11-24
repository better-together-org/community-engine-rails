# Test Coverage Improvement Plan

## Current Status
- **Coverage**: 77.45% line coverage
- **Issue**: 50+ spec files contain only stub tests (`it 'exists'`)
- **Goal**: Achieve 90%+ coverage with comprehensive, meaningful tests

## Coverage Gaps Analysis

### Critical Issues Found
1. **Core business logic untested**: Messaging, metrics tracking, comments
2. **Jobs with stub specs**: All 4 metrics tracking jobs
3. **Models with stub specs**: 30+ models with no real tests
4. **Helpers untested**: 15+ helper modules (lower priority)

## Implementation Plan

### PHASE 1: Critical Business Logic (HIGHEST PRIORITY)
**Estimated Impact**: +8-10% coverage | **Effort**: 2-3 hours

#### 1.1 Messaging System
- **File**: `spec/models/better_together/message_spec.rb`
- **Model**: `app/models/better_together/message.rb`
- **Status**: Factory exists ✅
- **Coverage needed**:
  - Associations: belongs_to :conversation, :sender
  - Validations: content presence
  - Action Text: encrypted rich text content
  - Callbacks: broadcast_append_later_to after create
  - Class methods: .permitted_attributes
- **Estimated examples**: 15-20

#### 1.2 Conversation System
- **File**: `spec/models/better_together/conversation_spec.rb`
- **Model**: `app/models/better_together/conversation.rb`
- **Status**: Factory exists ✅
- **Coverage needed**:
  - Associations: has_many :messages, :conversation_participants, :participants
  - Validations: at_least_one_participant, participant_ids presence, first_message_content_present
  - Encryption: title deterministic encryption
  - Nested attributes: messages_attributes
  - Instance methods: #first_message_content
  - Class methods: .permitted_attributes
- **Estimated examples**: 25-30

#### 1.3 Conversation Participants
- **File**: `spec/models/better_together/conversation_participant_spec.rb`
- **Model**: `app/models/better_together/conversation_participant.rb`
- **Status**: Factory exists ✅
- **Coverage needed**:
  - Associations: belongs_to :conversation, :person
  - Validations (if any)
  - Scopes (if any)
- **Estimated examples**: 10-15

#### 1.4 Metrics Tracking Jobs
**Files**:
- `spec/jobs/better_together/metrics/track_page_view_job_spec.rb`
- `spec/jobs/better_together/metrics/track_link_click_job_spec.rb`
- `spec/jobs/better_together/metrics/track_share_job_spec.rb`
- `spec/jobs/better_together/metrics/track_download_job_spec.rb`

**Coverage needed per job**:
- Job enqueuing
- Perform method creates metric record
- Handles required parameters
- Error handling
**Estimated examples**: 8-10 per job (32-40 total)

#### 1.5 Comment System
- **File**: `spec/models/better_together/comment_spec.rb`
- **Model**: `app/models/better_together/comment.rb`
- **Coverage needed**:
  - Polymorphic associations (commentable)
  - Author association
  - Validations
  - Content handling
- **Estimated examples**: 15-20

**Phase 1 Total**: ~100-125 examples

---

### PHASE 2: Core Data Models (HIGH PRIORITY)
**Estimated Impact**: +5-7% coverage | **Effort**: 2-3 hours

#### 2.1 Contact Information Models
**Files**:
- `spec/models/better_together/email_address_spec.rb` (factory exists ✅)
- `spec/models/better_together/phone_number_spec.rb`
- `spec/models/better_together/address_spec.rb`

**Coverage needed per model**:
- Associations with Person
- Format validations (email regex, phone formatting)
- Uniqueness/presence validations
- Scopes (primary, verified, etc.)
**Estimated examples**: 15-20 per model (45-60 total)

#### 2.2 File Management
- **File**: `spec/models/better_together/file_spec.rb`
- **Coverage needed**:
  - Active Storage attachments
  - Associations
  - Validations (file type, size)
  - Polymorphic uploadable
- **Estimated examples**: 20-25

#### 2.3 Metrics Models
**Files**:
- `spec/models/better_together/metrics/share_spec.rb`
- `spec/models/better_together/metrics/download_spec.rb`
- `spec/models/better_together/metrics/link_click_report_spec.rb`
- `spec/models/better_together/metrics/page_view_report_spec.rb`

**Coverage needed**:
- Polymorphic associations (shareable, downloadable)
- Timestamp tracking
- Aggregation methods (for report models)
- Scopes
**Estimated examples**: 12-15 per model (48-60 total)

**Phase 2 Total**: ~115-145 examples

---

### PHASE 3: Supporting Features (MEDIUM PRIORITY)
**Estimated Impact**: +3-5% coverage | **Effort**: 2-3 hours

#### 3.1 Events System
**Files**:
- `spec/models/better_together/calendar_entry_spec.rb`
- `spec/models/better_together/event_category_spec.rb`
- `spec/models/better_together/call_for_interest_spec.rb`

**Estimated examples**: 60-80 total

#### 3.2 Categorization
**Files**:
- `spec/models/better_together/category_spec.rb`
- `spec/models/better_together/categorization_spec.rb`
- `spec/models/better_together/contact_detail_spec.rb`

**Estimated examples**: 40-50 total

#### 3.3 Social & Security
**Files**:
- `spec/models/better_together/social_media_account_spec.rb`
- `spec/models/better_together/website_link_spec.rb`
- `spec/models/better_together/jwt_denylist_spec.rb`
- `spec/models/better_together/resource_permission_spec.rb`

**Estimated examples**: 50-60 total

**Phase 3 Total**: ~150-190 examples

---

### PHASE 4: Geography Models (LOWER PRIORITY)
**Estimated Impact**: +2-3% coverage | **Effort**: 3-4 hours

**Files** (11 models):
- Continent, Country, State, Region, Settlement
- Map, GeospatialSpace, RegionSettlement
- All use PostGIS, STI pattern, complex hierarchies

**Note**: Geography is a complete subsystem - defer unless coverage target not met

**Phase 4 Total**: ~120-150 examples

---

### PHASE 5: Helper Specs (LOWEST PRIORITY)
**Estimated Impact**: +1-2% coverage | **Effort**: 1-2 hours

**Files**: 15+ helper specs
**Note**: Helpers are typically trivial view helpers - only test if they contain business logic

**Phase 5 Total**: ~30-50 examples

---

## Execution Strategy

### Immediate Actions (Phase 1)
1. ✅ Start with messaging system (high business value)
2. ✅ Add metrics job specs (critical for analytics)
3. ✅ Cover comment system

### Next Steps (Phase 2)
4. Contact information models (email, phone, address)
5. File management
6. Metrics aggregation models

### Later (Phase 3+)
7. Events, categorization, social media
8. Geography subsystem if needed
9. Helpers only if coverage gaps remain

## Success Criteria

### Coverage Targets
- **After Phase 1**: ~85% coverage
- **After Phase 2**: ~90% coverage
- **After Phase 3**: ~93% coverage
- **Stretch goal**: ~95% coverage

### Quality Standards
Each spec must include:
- ✅ Factory tests (valid factory, custom attributes)
- ✅ Association tests (has_many, belongs_to, through, polymorphic)
- ✅ Validation tests (presence, format, uniqueness, custom)
- ✅ Scope tests (if scopes exist)
- ✅ Instance method tests
- ✅ Class method tests
- ✅ Callback tests (if callbacks exist)
- ✅ Integration tests for complex workflows

### Anti-Patterns to Avoid
- ❌ No stub `it 'exists'` tests
- ❌ No tests that just check class name
- ❌ No incomplete test suites
- ✅ Every test should verify actual behavior

## Estimated Total Effort
- **Phase 1**: 2-3 hours → ~85% coverage
- **Phase 2**: 2-3 hours → ~90% coverage  
- **Phase 3**: 2-3 hours → ~93% coverage
- **Total**: 6-9 hours to reach 90%+ coverage

## Dependencies & Blockers
- None identified - all models have basic structure
- Factories exist for core models
- Docker environment configured and working

## Next Steps
1. Begin Phase 1.1 (Message model spec)
2. Update this plan as coverage improves
3. Re-run coverage reports after each phase
4. Adjust priorities based on actual coverage impact
