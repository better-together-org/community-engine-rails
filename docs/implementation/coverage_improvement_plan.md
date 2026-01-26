# Test Coverage Improvement Implementation Plan

**Created:** November 24, 2025  
**Target:** Achieve 60%+ coverage on all 59 files currently below threshold  
**Current Overall Coverage:** 77.78%

## Executive Summary

- **Files needing work:** 59 files
- **Total uncovered lines:** 1,281 lines
- **Estimated test lines needed:** ~2,562 (2:1 test-to-code ratio)
- **Timeline:** 5 weeks
- **Approach:** Phased implementation, highest impact first

## Success Criteria

1. ✅ All 59 files reach 60%+ coverage
2. ✅ Overall coverage increases to 85%+
3. ✅ Zero files with 0% coverage
4. ✅ All critical subsystems (1-7) maintain 75%+ coverage

## Phase 1: Critical Files (0% Coverage) - Week 1

**Goal:** Eliminate all 0% coverage files  
**Files:** 4  
**Lines to cover:** 74  
**Estimated effort:** 2-3 days

### Files to Address

#### 1. `lib/better_together/configuration.rb` (12 lines)
- **Purpose:** Engine configuration management
- **Test Type:** Unit specs
- **Priority:** CRITICAL - used throughout engine
- **Test Focus:**
  - Configuration defaults
  - Configuration setters/getters
  - Block-based configuration
  - Configuration validation

#### 2. `lib/better_together/safe_class_resolver.rb` (16 lines)
- **Purpose:** Safe dynamic class resolution (security)
- **Test Type:** Unit specs
- **Priority:** CRITICAL - security component
- **Test Focus:**
  - Allow-list validation
  - Security edge cases (constantize attacks)
  - Error handling for invalid classes
  - Integration with concerns

#### 3. `lib/generators/better_together/install/install_generator.rb` (28 lines)
- **Purpose:** Rails generator for engine installation
- **Test Type:** Generator specs
- **Priority:** HIGH - installation workflow
- **Test Focus:**
  - File generation
  - Migration copying
  - Route injection
  - Configuration file creation

#### 4. `lib/mobility/backends/attachments.rb` (18 lines)
- **Purpose:** Custom Mobility backend for Active Storage
- **Test Type:** Unit/integration specs
- **Priority:** HIGH - i18n functionality
- **Test Focus:**
  - Attachment association
  - Translation storage/retrieval
  - Locale switching
  - Fallback behavior

### Implementation Steps

```bash
# Week 1, Day 1-2: Library specs
bin/dc-run rails generate rspec:model BetterTogether::Configuration --skip
# Edit spec/lib/better_together/configuration_spec.rb
bin/dc-run bundle exec rspec spec/lib/better_together/configuration_spec.rb

bin/dc-run rails generate rspec:model BetterTogether::SafeClassResolver --skip
# Edit spec/lib/better_together/safe_class_resolver_spec.rb
bin/dc-run bundle exec rspec spec/lib/better_together/safe_class_resolver_spec.rb

# Week 1, Day 3: Generator and Mobility backend
# Create spec/lib/generators/better_together/install/install_generator_spec.rb
# Create spec/lib/mobility/backends/attachments_spec.rb
bin/dc-run bundle exec rspec spec/lib/
```

## Phase 2: High Priority (1-30% Coverage) - Week 2-3

**Goal:** Bring all files with <30% coverage to 60%+  
**Files:** 15  
**Lines to cover:** 470 uncovered lines  
**Estimated effort:** 8-10 days

### Subsystem Breakdown

#### Platform Management (4 files, 83 uncovered lines)

1. **`controllers/better_together/setup_wizard_steps_controller.rb`** (20.6%, 54 uncovered)
   - Add request specs for wizard step navigation
   - Test step validation and progression
   - Test step completion tracking
   - Target: 75%+

2. **`mailers/better_together/platform_invitation_mailer.rb`** (23.1%, 10 uncovered)
   - Test email generation for all invitation states
   - Test localization of email content
   - Test attachment handling
   - Target: 90%+

3. **`jobs/better_together/platform_invitation_mailer_job.rb`** (26.7%, 11 uncovered)
   - Test job enqueuing
   - Test mailer invocation
   - Test error handling/retries
   - Target: 85%+

4. **`controllers/better_together/translations_controller.rb`** (27.3%, 8 uncovered)
   - Test translation CRUD operations
   - Test locale switching
   - Test translation export/import
   - Target: 70%+

#### Community Management (11 files, 387 uncovered lines)

1. **`helpers/better_together/sidebar_nav_helper.rb`** (10.9%, 41 uncovered)
   - Test navigation menu generation
   - Test active state detection
   - Test permission-based filtering
   - Target: 80%+

2. **`mailers/better_together/authorship_mailer.rb`** (15.8%, 16 uncovered)
   - Test content authorship notifications
   - Test localization
   - Target: 90%+

3. **`controllers/better_together/metrics/reports_controller.rb`** (20.0%, 20 uncovered)
   - Test report generation
   - Test filtering and date ranges
   - Test export formats (CSV, PDF)
   - Target: 75%+

4. **`lib/better_together/migration_helpers.rb`** (23.5%, 13 uncovered)
   - Test migration helper methods
   - Test table creation helpers
   - Test column definition helpers
   - Target: 85%+

5. **`robots/better_together/translation_bot.rb`** (25.9%, 20 uncovered)
   - Test automated translation detection
   - Test translation suggestions
   - Target: 70%+

6. **`builders/better_together/joatu_demo_builder.rb`** (27.0%, 54 uncovered)
   - Test demo data generation
   - Test Joatu-specific fixtures
   - Target: 65%+

7. **`lib/jsonapi/link_builder.rb`** (27.6%, 55 uncovered)
   - Test JSONAPI link generation
   - Test pagination links
   - Test relationship links
   - Target: 75%+

8. **`models/better_together/metrics/link_checker_report.rb`** (28.4%, 48 uncovered)
   - Test broken link detection
   - Test report generation
   - Test link validation
   - Target: 70%+

9. **`helpers/better_together/hub_helper.rb`** (28.6%, 15 uncovered)
   - Test hub navigation helpers
   - Test community hub widgets
   - Target: 75%+

10. **`sanitizers/better_together/sanitizers/external_link_icon_sanitizer.rb`** (28.6%, 10 uncovered)
    - Test HTML sanitization
    - Test icon injection for external links
    - Target: 85%+

11. **`models/better_together/metrics/page_view_report.rb`** (29.1%, 95 uncovered)
    - Test page view aggregation
    - Test date range filtering
    - Test report generation
    - Target: 70%+

### Implementation Steps

```bash
# Week 2: Controllers and Mailers
for file in setup_wizard_steps platform_invitation_mailer translations; do
  # Add comprehensive request/mailer specs
  bin/dc-run bundle exec rspec spec/**/*${file}*_spec.rb
done

# Week 3: Helpers, Models, and Utilities
for file in sidebar_nav hub_helper link_checker page_view_report; do
  # Add unit specs for each component
  bin/dc-run bundle exec rspec spec/**/*${file}*_spec.rb
done
```

## Phase 3: Medium Priority (30-60% Coverage) - Week 4-5

**Goal:** Bring all remaining files to 60%+  
**Files:** 40  
**Lines to cover:** 737 uncovered lines  
**Estimated effort:** 8-10 days

### Key Files (Top 15 by impact)

1. **`lib/better_together/column_definitions.rb`** (31.0%, 40 uncovered)
   - Test column helper methods for migrations
   - Target: 75%+

2. **`future_controllers/better_together/bt/api/registrations_controller.rb`** (31.4%, 24 uncovered)
   - Test API user registration
   - Target: 75%+

3. **`controllers/better_together/help_preferences_controller.rb`** (35.0%, 13 uncovered)
   - Test help preference CRUD
   - Target: 70%+

4. **`mailers/better_together/event_invitations_mailer.rb`** (37.5%, 10 uncovered)
   - Test event invitation emails
   - Target: 90%+

5. **`controllers/better_together/hub_controller.rb`** (40.0%, 6 uncovered)
   - Test hub dashboard rendering
   - Target: 75%+

6. **`models/concerns/better_together/geography/iso_location.rb`** (40.0%, 12 uncovered)
   - Test ISO location validation
   - Target: 85%+

7. **`models/better_together/metrics/link_click_report.rb`** (40.6%, 57 uncovered)
   - Test link click aggregation
   - Target: 70%+

8. **`controllers/better_together/person_platform_memberships_controller.rb`** (40.6%, 19 uncovered)
   - Test membership management
   - Target: 75%+

9. **`controllers/better_together/geography/continents_controller.rb`** (42.4%, 19 uncovered)
   - Test geography CRUD
   - Target: 75%+

10. **`controllers/better_together/agreements_controller.rb`** (43.8%, 9 uncovered)
    - Test Joatu agreement workflows
    - Target: 75%+

11. **`builders/better_together/geography_builder.rb`** (44.1%, 38 uncovered)
    - Test geography data seeding
    - Target: 70%+

12. **`controllers/concerns/better_together/wizard_methods.rb`** (45.0%, 22 uncovered)
    - Test wizard controller concern
    - Target: 80%+

13. **`controllers/better_together/content/page_blocks_controller.rb`** (45.8%, 13 uncovered)
    - Test page block CRUD
    - Target: 75%+

14. **`controllers/better_together/resource_permissions_controller.rb`** (46.3%, 22 uncovered)
    - Test permission management
    - Target: 75%+

15. **`helpers/better_together/i18n_helper.rb`** (48.0%, 13 uncovered)
    - Test i18n helper methods
    - Target: 85%+

### Remaining 25 Files (50-60% range)

These files are close to the target and will be addressed systematically:

- Controllers: 12 files (average 53.2% coverage)
- Models: 8 files (average 54.8% coverage)
- Helpers: 3 files (average 52.1% coverage)
- Other: 2 files (average 51.5% coverage)

### Implementation Steps

```bash
# Week 4: Controllers 30-50%
# Focus on request specs for all controllers
bin/dc-run bundle exec rspec spec/requests/better_together/

# Week 5: Models and Helpers 50-60%
# Add missing spec coverage for edge cases
bin/dc-run bundle exec rspec spec/models/better_together/
bin/dc-run bundle exec rspec spec/helpers/better_together/
```

## Testing Patterns by File Type

### Controllers (Request Specs)

```ruby
RSpec.describe BetterTogether::SomeController, type: :request do
  before { configure_host_platform }

  describe "GET #index" do
    context "when authenticated" do
      before { login('user@example.com', 'password') }
      
      it "returns success" do
        get some_path
        expect(response).to have_http_status(:success)
      end
    end

    context "when not authenticated" do
      it "redirects to login" do
        get some_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "POST #create" do
    let(:valid_params) { { some: { attr: 'value' } } }
    
    it "creates resource" do
      expect {
        post some_path, params: valid_params
      }.to change(SomeModel, :count).by(1)
    end
  end
end
```

### Mailers (Mailer Specs)

```ruby
RSpec.describe BetterTogether::SomeMailer, type: :mailer do
  describe "#notification" do
    let(:user) { create(:better_together_user) }
    let(:mail) { described_class.notification(user) }

    it "renders the subject" do
      expect(mail.subject).to eq("Expected Subject")
    end

    it "renders the receiver email" do
      expect(mail.to).to eq([user.email])
    end

    it "renders the sender email" do
      expect(mail.from).to eq(["noreply@example.com"])
    end

    it "includes expected content" do
      expect(mail.body.encoded).to include("Expected text")
    end

    it "uses correct locale" do
      I18n.with_locale(:es) do
        expect(mail.subject).to eq("Asunto Esperado")
      end
    end
  end
end
```

### Jobs (Job Specs)

```ruby
RSpec.describe BetterTogether::SomeJob, type: :job do
  describe "#perform" do
    let(:record) { create(:better_together_record) }

    it "enqueues job" do
      expect {
        described_class.perform_later(record)
      }.to have_enqueued_job(described_class)
    end

    it "processes successfully" do
      expect {
        described_class.new.perform(record)
      }.to change { record.reload.status }.to("processed")
    end

    it "handles errors gracefully" do
      allow(record).to receive(:process!).and_raise(StandardError)
      
      expect {
        described_class.new.perform(record)
      }.to raise_error(StandardError)
    end
  end
end
```

### Helpers (Helper Specs)

```ruby
RSpec.describe BetterTogether::SomeHelper, type: :helper do
  describe "#some_helper_method" do
    it "returns expected output" do
      expect(helper.some_helper_method("input")).to eq("expected")
    end

    it "handles nil input" do
      expect(helper.some_helper_method(nil)).to be_nil
    end

    it "handles edge cases" do
      expect(helper.some_helper_method("")).to eq("")
    end
  end

  describe "#navigation_helper" do
    before { configure_host_platform }

    it "generates correct HTML" do
      result = helper.navigation_helper
      expect(result).to include('nav')
      expect(result).to be_html_safe
    end
  end
end
```

### Models (Model Specs)

```ruby
RSpec.describe BetterTogether::SomeModel, type: :model do
  subject(:model) { build(:better_together_some_model) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:required_field) }
    it { is_expected.to validate_uniqueness_of(:unique_field) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:parent) }
    it { is_expected.to have_many(:children) }
  end

  describe "#custom_method" do
    it "returns expected value" do
      expect(model.custom_method).to eq("expected")
    end

    context "with special conditions" do
      before { model.flag = true }

      it "returns different value" do
        expect(model.custom_method).to eq("different")
      end
    end
  end
end
```

### Libraries (Unit Specs)

```ruby
RSpec.describe BetterTogether::SomeLibrary do
  describe ".class_method" do
    it "performs expected operation" do
      result = described_class.class_method(arg)
      expect(result).to eq(expected)
    end

    it "raises error on invalid input" do
      expect {
        described_class.class_method(invalid)
      }.to raise_error(ArgumentError)
    end
  end

  describe "#instance_method" do
    subject(:instance) { described_class.new(config) }

    it "maintains configuration" do
      expect(instance.config).to eq(config)
    end

    it "executes successfully" do
      expect(instance.instance_method).to be_truthy
    end
  end
end
```

## Daily Workflow

1. **Morning:** Pick 2-3 files from current phase
2. **Write tests:** Focus on one file at a time
3. **Run tests:** `bin/dc-run bundle exec rspec spec/path/to/file_spec.rb`
4. **Check coverage:** Verify file reaches 60%+ (ideally 80%+)
5. **Commit:** Small, focused commits per file
6. **End of day:** Run full suite to ensure no regressions

## Continuous Monitoring

```bash
# After each file
bin/dc-run bundle exec rspec spec/path/to/new_spec.rb
open coverage/index.html  # Verify improvement

# Daily
bin/dc-run bundle exec rspec
# Check overall coverage percentage

# Weekly
# Review coverage report for new gaps
# Adjust plan based on progress
```

## Success Metrics

Track these metrics weekly:

- Number of files under 60%: Start 59 → Target 0
- Overall coverage: Start 77.78% → Target 85%+
- Files with 0% coverage: Start 4 → Target 0
- Average subsystem coverage: Start ~80% → Target 85%+

## Risk Mitigation

1. **Complex dependencies:** Start simple, add mocks as needed
2. **Time overruns:** Prioritize based on file criticality
3. **Regression:** Run full suite before committing
4. **Coverage plateau:** Focus on edge cases and error paths

## Completion Checklist

- [ ] Phase 1: All 4 files at 60%+
- [ ] Phase 2: All 15 files at 60%+
- [ ] Phase 3: All 40 files at 60%+
- [ ] Zero files with <60% coverage
- [ ] Overall coverage ≥85%
- [ ] All subsystems ≥75% coverage
- [ ] CI coverage checks passing
- [ ] Documentation updated

## Next Steps

1. ✅ Review and approve this plan
2. 🔄 Begin Phase 1: Week 1, Day 1
3. 📊 Set up daily coverage tracking
4. 🎯 Target completion: 5 weeks from start
