# TDD Acceptance Criteria Template

## Overview

This template guides the creation of stakeholder-focused acceptance criteria for implementing features using Test-Driven Development (TDD). Use this template to transform confirmed implementation plans into specific, testable acceptance criteria.

## Template Usage Instructions

1. **Start with Confirmed Implementation Plan**: Ensure the implementation plan has passed collaborative review
2. **Identify Affected Stakeholders**: Determine which stakeholder roles will interact with this feature
3. **Define Acceptance Criteria**: Create specific, testable criteria for each stakeholder
4. **Generate Test Structure**: Outline the test coverage needed for each acceptance criteria
5. **Validate with Stakeholders**: Confirm acceptance criteria match stakeholder needs before implementation

---

## Feature: [FEATURE_NAME]

### Implementation Plan Reference
- **Plan Document**: `docs/[implementation_plan_file].md`
- **Review Status**: ✅ Collaborative Review Completed
- **Approval Date**: [DATE]
- **Technical Approach Confirmed**: [Brief summary of technical decisions]

### Stakeholder Impact Analysis
- **Primary Stakeholders**: [List primary stakeholders affected]
- **Secondary Stakeholders**: [List secondary stakeholders affected] 
- **Cross-Stakeholder Workflows**: [Identify workflows spanning multiple stakeholder types]

---

## Phase [X]: [PHASE_NAME]

### [Feature Number]. [Feature Name]

#### End User Acceptance Criteria
**As an end user, I want [capability] so that [benefit].**

- [ ] **AC-[#].1**: [Specific, testable behavior that delivers direct user value]
- [ ] **AC-[#].2**: [User interface interaction requirement]
- [ ] **AC-[#].3**: [User safety or privacy protection requirement]
- [ ] **AC-[#].4**: [User feedback/notification requirement]
- [ ] **AC-[#].5**: [User error handling requirement]
- [ ] **AC-[#].6**: [User accessibility requirement]

#### Community Organizer Acceptance Criteria
**As a community organizer, I want [organizational capability] so that [community benefit].**

- [ ] **AC-[#].7**: [Community management capability requirement]
- [ ] **AC-[#].8**: [Community moderation requirement]
- [ ] **AC-[#].9**: [Community analytics/insight requirement]
- [ ] **AC-[#].10**: [Community member relationship management requirement]

#### Platform Organizer Acceptance Criteria
**As a platform organizer, I want [platform oversight] so that [platform-wide benefit].**

- [ ] **AC-[#].11**: [Platform-wide policy enforcement requirement]
- [ ] **AC-[#].12**: [Platform analytics and reporting requirement]
- [ ] **AC-[#].13**: [Platform configuration management requirement]
- [ ] **AC-[#].14**: [Platform compliance and audit requirement]

#### [Additional Stakeholder Role] Acceptance Criteria
**As a [stakeholder role], I want [specific capability] so that [role-specific benefit].**

- [ ] **AC-[#].15**: [Role-specific requirement]
- [ ] **AC-[#].16**: [Role-specific workflow requirement]

---

## TDD Test Structure

### Test Coverage Matrix

| Acceptance Criteria | Model Tests | Controller Tests | Feature Tests | Integration Tests |
|-------------------|-------------|------------------|---------------|-------------------|
| AC-[#].1 | ✓ | ✓ | ✓ | |
| AC-[#].2 | | ✓ | ✓ | |
| AC-[#].3 | ✓ | ✓ | | ✓ |
| AC-[#].4 | | ✓ | ✓ | |

### Test Implementation Plan

#### Model Tests
```ruby
# Test file: spec/models/better_together/[model_name]_spec.rb
RSpec.describe BetterTogether::[ModelName] do
  describe '[business logic method]' do
    context 'when [condition from AC-[#].1]' do
      it '[expected behavior from acceptance criteria]' do
        # Test implementation validates AC-[#].1
      end
    end
  end
end
```

#### Controller Tests
```ruby
# Test file: spec/controllers/better_together/[controller_name]_spec.rb
RSpec.describe BetterTogether::[ControllerName]Controller do
  describe '[action]' do
    context 'when [stakeholder role] [performs action]' do
      it '[expected response from acceptance criteria]' do
        # Test implementation validates AC-[#].2
      end
    end
  end
end
```

#### Feature Tests
```ruby
# Test file: spec/features/[feature_name]_spec.rb
RSpec.feature '[Feature Name]' do
  scenario '[stakeholder] [performs workflow from acceptance criteria]' do
    # Test implementation validates complete stakeholder journey
    # Covers multiple acceptance criteria in realistic workflow
  end
end
```

#### Background Job Tests
```ruby
# Test file: spec/jobs/better_together/[job_name]_spec.rb
RSpec.describe BetterTogether::[JobName] do
  describe '#perform' do
    it '[expected job behavior from acceptance criteria]' do
      # Test implementation validates background processing requirements
    end
  end
end
```

#### Mailer Tests
```ruby
# Test file: spec/mailers/better_together/[mailer_name]_spec.rb
RSpec.describe BetterTogether::[MailerName] do
  describe '[mailer method]' do
    it '[expected email behavior from acceptance criteria]' do
      # Test implementation validates notification requirements
    end
  end
end
```

---

## Implementation Sequence

### Red-Green-Refactor Cycle for Each Acceptance Criteria

1. **RED Phase**: Write failing test that validates specific acceptance criteria
   ```bash
   # Run specific test to confirm it fails appropriately
   bundle exec rspec spec/[test_file]_spec.rb:[line_number]
   ```

2. **GREEN Phase**: Write minimal code to make test pass
   ```bash
   # Run test again to confirm it passes
   bundle exec rspec spec/[test_file]_spec.rb:[line_number]
   ```

3. **REFACTOR Phase**: Improve code while maintaining passing test
   ```bash
   # Run full test suite to ensure no regressions
   bundle exec rspec
   ```

### Validation Checkpoints

#### After Each Acceptance Criteria Implementation
- [ ] All related tests pass
- [ ] No existing tests broken
- [ ] Security scan passes: `bundle exec brakeman --quiet --no-pager`
- [ ] Accessibility checks pass for UI changes
- [ ] Performance benchmarks met for new functionality

#### After Complete Feature Implementation
- [ ] **Stakeholder Demo**: Present working feature to relevant stakeholders
- [ ] **Acceptance Review**: Validate all acceptance criteria fulfilled
- [ ] **Documentation Updated**: Update system documentation and diagrams
- [ ] **Integration Testing**: Verify feature works with existing systems

---

## Customization Guidelines

### Stakeholder Role Customization
- **Replace `[stakeholder role]`** with specific roles relevant to your feature
- **Add additional stakeholder sections** as needed for complex features
- **Remove stakeholder sections** that don't apply to simpler features

### Acceptance Criteria Patterns
- **User-facing criteria**: Focus on interface, safety, and experience
- **Organizer criteria**: Focus on management, oversight, and community health
- **System criteria**: Focus on performance, security, and maintainability

### Test Structure Adaptation
- **Simple features**: May only need model and controller tests
- **Complex features**: Require full test matrix including integration tests
- **UI-heavy features**: Emphasize feature tests and accessibility validation
- **API features**: Focus on controller tests and integration tests

---

## Quality Standards

### Acceptance Criteria Requirements
- **Specific**: Each criteria defines one clear, testable behavior
- **Measurable**: Success/failure can be objectively determined
- **Achievable**: Criteria can be implemented with available resources
- **Relevant**: Criteria directly serve identified stakeholder needs
- **Time-bound**: Criteria include performance and response time expectations where applicable

### Test Quality Requirements
- **Comprehensive**: Every acceptance criteria has corresponding test coverage
- **Isolated**: Tests can run independently without dependencies
- **Deterministic**: Tests produce consistent results across runs
- **Maintainable**: Tests clearly express intent and are easy to update
- **Fast**: Test suite completes in reasonable time for development workflow

---

This template ensures systematic transformation of implementation plans into stakeholder-focused acceptance criteria with comprehensive test coverage.
