# SafeClassResolver - Security Utility Reference

## ⚠️ RETROSPECTIVE DOCUMENTATION

**This is retrospective documentation for already-implemented functionality in PR #1149 (merged November 2025).**

This reference documents the SafeClassResolver security utility that prevents unsafe reflection and constantize vulnerabilities throughout the Better Together Community Engine.

---

## Overview

SafeClassResolver is a security utility module that provides safe class name resolution from untrusted input. It prevents the security vulnerability of calling `constantize` or `safe_constantize` on arbitrary user-supplied strings by requiring explicit allow-lists of permitted class names.

**Key Security Protection:**
- **Prevents unsafe reflection**: Never resolves class names not in explicit allow-list
- **Blocks code injection**: Rejects malicious inputs like `` `rm -rf /` `` or `File.delete(...)`
- **No arbitrary constantize**: All class resolution must go through allow-list validation
- **Brakeman compliance**: Eliminates "Dangerous use of constantize" warnings

**Brakeman Context:**
SafeClassResolver was created to fix Brakeman's UnsafeReflection warnings. The engine previously used `constantize` on user input in several locations, creating potential security vulnerabilities. This utility provides a safe alternative pattern.

## Architecture

SafeClassResolver exists in two locations with slightly different implementations:

### 1. Lib Module (lib/better_together/safe_class_resolver.rb)

**Purpose**: Original simpler implementation for basic use cases

**Key Methods:**
- `resolve(candidate, allowed: [])` - Returns class or nil
- `resolve!(candidate, allowed:, error_class: ArgumentError)` - Returns class or raises

**Implementation Pattern:**
```ruby
module BetterTogether
  module SafeClassResolver
    module_function
    
    def resolve(candidate, allowed: [])
      return nil if candidate.blank?
      
      allowed_names = Array(allowed).map { |a| a.is_a?(Class) ? a.name : a.to_s }
      return nil unless allowed_names.include?(candidate.to_s)
      
      candidate.to_s.safe_constantize
    end
  end
end
```

### 2. Service Module (app/services/better_together/safe_class_resolver.rb)

**Purpose**: Enhanced implementation with namespace normalization and safer constantize

**Key Differences:**
- Normalizes class names (removes leading `::`)
- Uses custom `constantize_safely` instead of Rails' `safe_constantize`
- More detailed error messages on `resolve!` failure

**Implementation Pattern:**
```ruby
module BetterTogether
  module SafeClassResolver
    module_function
    
    def resolve(name, allowed: [])
      normalized = normalize_name(name)
      return nil if normalized.nil?
      return nil unless allowed&.include?(normalized)
      
      constantize_safely(normalized)
    rescue NameError
      nil
    end
    
    private
    
    def constantize_safely(qualified_name)
      names = qualified_name.split('::')
      names.shift if names.first.blank?
      
      constant = Object
      names.each { |n| constant = constant.const_get(n) }
      constant
    end
  end
end
```

**Recommendation**: Use the service module version (`app/services/...`) for new code as it provides enhanced safety and normalization.

## Usage Patterns

### Basic Class Resolution

**Scenario**: Resolve a class name from user input or parameter

```ruby
# User provides category type via form parameter
category_class_name = params[:category_class]  # => "BetterTogether::Geography::Country"

# Define allowed categories
ALLOWED_CATEGORIES = [
  'BetterTogether::Geography::Country',
  'BetterTogether::Geography::State', 
  'BetterTogether::Geography::Settlement'
]

# Safely resolve the class
category_class = BetterTogether::SafeClassResolver.resolve(
  category_class_name,
  allowed: ALLOWED_CATEGORIES
)

if category_class
  # Safe to use resolved class
  @categories = category_class.all
else
  # Invalid or disallowed class name
  render_error "Invalid category type"
end
```

### Resolve with Exception

**Scenario**: Need to raise an error when class resolution fails

```ruby
# Controller action requiring valid resource class
def create
  # Will raise ArgumentError if class not in allow-list
  form_class = BetterTogether::SafeClassResolver.resolve!(
    params[:form_type],
    allowed: ALLOWED_FORM_CLASSES,
    error_class: ArgumentError
  )
  
  @form = form_class.new(form_params)
  # ... continue with form processing
end
```

### Allow-List with Class Objects

**Scenario**: Allow-list specified using actual class constants

```ruby
# Allow-list defined with class objects (preferred for type safety)
ALLOWED_SHAREABLES = [
  BetterTogether::Content::Block,
  BetterTogether::Page,
  BetterTogether::Community
]

# Resolve class from polymorphic type parameter
shareable_class = BetterTogether::SafeClassResolver.resolve(
  params[:shareable_type],
  allowed: ALLOWED_SHAREABLES
)
```

### Mixed Allow-List (Strings and Classes)

**Scenario**: Allow-list with both string names and class constants

```ruby
# Allow-list mixing strings and classes
ALLOWED_RESOURCES = [
  BetterTogether::Person,              # Class constant
  'BetterTogether::Community',         # String name
  'BetterTogether::Geography::Country' # Namespaced string
]

# Resolver handles both types automatically
resource_class = BetterTogether::SafeClassResolver.resolve(
  params[:resource_type],
  allowed: ALLOWED_RESOURCES
)
```

## Real-World Integration Examples

### 1. Categorizable Concern (Dynamic Category Classes)

**File**: `app/models/concerns/better_together/categorizable.rb`

**Use Case**: Models can be categorized by different category types (Country, State, etc.)

```ruby
module BetterTogether
  module Categorizable
    extend ActiveSupport::Concern
    
    included do
      # Polymorphic association to categories
      has_many :categorizations, as: :categorizable
      has_many :categories, through: :categorizations
    end
    
    class_methods do
      # Define allowed category classes for this model
      def allowed_category_classes
        raise NotImplementedError, "#{name} must define allowed_category_classes"
      end
    end
    
    # Add a category with type validation
    def add_category(category_class_name, category_id)
      # SECURITY: Use SafeClassResolver to prevent unsafe constantize
      category_class = BetterTogether::SafeClassResolver.resolve!(
        category_class_name,
        allowed: self.class.allowed_category_classes
      )
      
      category = category_class.find(category_id)
      categories << category unless categories.include?(category)
    end
  end
end
```

**Model Implementation:**
```ruby
class BetterTogether::Person < ApplicationRecord
  include BetterTogether::Categorizable
  
  # Specify which category types are allowed for people
  def self.allowed_category_classes
    [
      'BetterTogether::Geography::Country',
      'BetterTogether::Geography::State',
      'BetterTogether::Skill',
      'BetterTogether::Interest'
    ]
  end
end
```

### 2. Roles Helper (Resource Type Resolution)

**File**: `app/helpers/better_together/roles_helper.rb`

**Use Case**: Display roles scoped to specific resource types

```ruby
module BetterTogether
  module RolesHelper
    ALLOWED_RESOURCE_CLASSES = [
      'BetterTogether::Platform',
      'BetterTogether::Community'
    ]
    
    def roles_for_resource(resource_class_name)
      # Safely resolve resource class from user selection
      resource_klass = BetterTogether::SafeClassResolver.resolve(
        resource_class_name,
        allowed: ALLOWED_RESOURCE_CLASSES
      )
      
      return [] unless resource_klass
      
      # Safe to query roles for this resource type
      BetterTogether::Role.where(resource_type: resource_klass.name)
    end
  end
end
```

### 3. Wizard Steps Controller (Form Class Resolution)

**File**: `app/controllers/better_together/wizard_steps_controller.rb`

**Use Case**: Multi-step wizard with different form classes per step

```ruby
module BetterTogether
  class WizardStepsController < ApplicationController
    ALLOWED_FORM_CLASSES = [
      'BetterTogether::PlatformSetup::BasicSettingsForm',
      'BetterTogether::PlatformSetup::CommunityForm',
      'BetterTogether::PlatformSetup::InvitationSettingsForm'
    ]
    
    def create
      # SECURITY: Resolve form class from step parameter using allow-list
      form_class = BetterTogether::SafeClassResolver.resolve!(
        params[:form_class],
        allowed: ALLOWED_FORM_CLASSES,
        error_class: ArgumentError
      )
      
      @form = form_class.new(wizard_step_params)
      
      if @form.save
        redirect_to next_step_path
      else
        render :new
      end
    end
  end
end
```

### 4. Metrics Track Share Job (Background Job Safety)

**File**: `app/jobs/better_together/metrics/track_share_job.rb`

**Use Case**: Background job tracking shares of different shareable types

```ruby
module BetterTogether
  module Metrics
    class TrackShareJob < ApplicationJob
      queue_as :metrics
      
      ALLOWED_SHAREABLES = [
        'BetterTogether::Content::Block',
        'BetterTogether::Page',
        'BetterTogether::Community',
        'BetterTogether::Event'
      ]
      
      def perform(shareable_type, shareable_id, platform_id)
        # SECURITY: Validate shareable type before querying database
        klass = BetterTogether::SafeClassResolver.resolve(
          shareable_type,
          allowed: ALLOWED_SHAREABLES
        )
        
        return unless klass  # Invalid type, skip tracking
        
        shareable = klass.find_by(id: shareable_id)
        return unless shareable
        
        # Safe to track metrics for validated shareable
        track_share_event(shareable, platform_id)
      end
    end
  end
end
```

## Security Considerations

### What SafeClassResolver Prevents

#### 1. Arbitrary Code Execution

**Vulnerable Code (NEVER DO THIS):**
```ruby
# ❌ DANGEROUS: User can execute arbitrary code
class_name = params[:class]  # User sends: "File.delete('/etc/passwd')"
klass = class_name.constantize  # Executes malicious code!
```

**Safe Alternative:**
```ruby
# ✅ SAFE: User input validated against allow-list
class_name = params[:class]
klass = BetterTogether::SafeClassResolver.resolve(
  class_name,
  allowed: ['BetterTogether::Person', 'BetterTogether::Community']
)
# => nil (malicious input rejected)
```

#### 2. Brakeman UnsafeReflection Warnings

**Vulnerable Pattern:**
```ruby
# app/models/my_model.rb
def dynamic_class_lookup
  # Brakeman warning: Unsafe reflection method constantize called with parameter value
  params[:type].constantize  
end
```

**Fixed with SafeClassResolver:**
```ruby
def dynamic_class_lookup
  # Brakeman: No warning, input validated
  BetterTogether::SafeClassResolver.resolve(
    params[:type],
    allowed: ALLOWED_TYPES
  )
end
```

#### 3. SQL Injection via Class Names

**Vulnerable Code:**
```ruby
# ❌ DANGEROUS: Class name interpolated into query
type = params[:type]  # User sends: "'; DROP TABLE users; --"
klass = type.safe_constantize
klass.where(active: true)  # May execute unexpected SQL
```

**Safe Alternative:**
```ruby
# ✅ SAFE: Only allowed class names can be used
klass = BetterTogether::SafeClassResolver.resolve(
  params[:type],
  allowed: ALLOWED_CLASSES
)
return unless klass  # Reject invalid types early
klass.where(active: true)  # Safe query
```

### Best Practices

#### 1. Define Allow-Lists as Constants

**Recommended Pattern:**
```ruby
class MyController < ApplicationController
  # Define allow-list at class level for clarity and reusability
  ALLOWED_RESOURCE_TYPES = [
    'BetterTogether::Person',
    'BetterTogether::Community',
    'BetterTogether::Platform'
  ]
  
  def index
    resource_class = BetterTogether::SafeClassResolver.resolve(
      params[:type],
      allowed: ALLOWED_RESOURCE_TYPES
    )
    # ...
  end
end
```

**Why**: Constants make allow-lists explicit, testable, and auditable.

#### 2. Use Concern-Based Allow-Lists for Flexibility

**Advanced Pattern:**
```ruby
# app/models/concerns/better_together/joatu_sourceable.rb
module BetterTogether
  module JoatuSourceable
    extend ActiveSupport::Concern
    
    # Self-registering allow-list via concern
    class_methods do
      def included_in_models
        @included_in_models ||= []
      end
      
      def included(base)
        super
        included_in_models << base.name
      end
    end
  end
end

# Usage in models
class BetterTogether::Skill < ApplicationRecord
  include BetterTogether::JoatuSourceable  # Auto-registers
end

# Controller can use dynamic allow-list
BetterTogether::SafeClassResolver.resolve(
  params[:source_class],
  allowed: BetterTogether::JoatuSourceable.included_in_models
)
```

**Why**: Scales better when new models are added—no need to update multiple allow-list constants.

#### 3. Handle Resolution Failures Gracefully

**Recommended Error Handling:**
```ruby
def process_resource
  resource_class = BetterTogether::SafeClassResolver.resolve(
    params[:resource_type],
    allowed: ALLOWED_RESOURCES
  )
  
  if resource_class.nil?
    # Log the attempt for security monitoring
    Rails.logger.warn "Invalid resource type attempted: #{params[:resource_type]}"
    
    # Return user-friendly error
    flash[:error] = t('.invalid_resource_type')
    redirect_to root_path
    return
  end
  
  # Continue with valid class
  @resources = resource_class.where(active: true)
end
```

#### 4. Test Allow-Lists Comprehensively

**Recommended Test Pattern:**
```ruby
RSpec.describe MyController do
  describe 'resource type resolution' do
    it 'allows all specified resource types' do
      MyController::ALLOWED_RESOURCES.each do |allowed_class|
        result = BetterTogether::SafeClassResolver.resolve(
          allowed_class,
          allowed: MyController::ALLOWED_RESOURCES
        )
        expect(result).not_to be_nil
      end
    end
    
    it 'rejects disallowed resource types' do
      disallowed = 'BetterTogether::SensitiveData'
      result = BetterTogether::SafeClassResolver.resolve(
        disallowed,
        allowed: MyController::ALLOWED_RESOURCES
      )
      expect(result).to be_nil
    end
    
    it 'rejects malicious inputs' do
      malicious_inputs = [
        'File.delete("/etc/passwd")',
        '`rm -rf /`',
        'Kernel.system("echo hacked")'
      ]
      
      malicious_inputs.each do |input|
        result = BetterTogether::SafeClassResolver.resolve(
          input,
          allowed: MyController::ALLOWED_RESOURCES
        )
        expect(result).to be_nil
      end
    end
  end
end
```

## API Reference

### `resolve(candidate, allowed: [])`

Safely resolves a class name if it's in the allow-list.

**Parameters:**
- `candidate` (String, Symbol) - Class name to resolve (e.g., "BetterTogether::Person")
- `allowed` (Array<String|Class>) - Allow-list of permitted class names or class constants

**Returns:**
- `Class` if candidate is in allow-list and exists
- `nil` if candidate is blank, not in allow-list, or doesn't exist

**Examples:**
```ruby
# With string allow-list
SafeClassResolver.resolve('String', allowed: ['String', 'Integer'])
# => String

# With class allow-list
SafeClassResolver.resolve('BetterTogether::Person', allowed: [BetterTogether::Person])
# => BetterTogether::Person

# Not in allow-list
SafeClassResolver.resolve('File', allowed: ['String'])
# => nil

# Blank input
SafeClassResolver.resolve('', allowed: ['String'])
# => nil

# Non-existent class
SafeClassResolver.resolve('NonExistent', allowed: ['NonExistent'])
# => nil
```

### `resolve!(candidate, allowed:, error_class: ArgumentError)`

Resolves a class name or raises an error.

**Parameters:**
- `candidate` (String, Symbol) - Class name to resolve
- `allowed` (Array<String|Class>) - Allow-list of permitted classes
- `error_class` (Class) - Exception class to raise on failure (default: ArgumentError)

**Returns:**
- `Class` if candidate is in allow-list and exists

**Raises:**
- `error_class` if candidate is not in allow-list or doesn't exist

**Examples:**
```ruby
# Successful resolution
SafeClassResolver.resolve!('String', allowed: ['String'])
# => String

# Disallowed class
SafeClassResolver.resolve!('File', allowed: ['String'])
# => ArgumentError: Disallowed class: File

# Custom error class
SafeClassResolver.resolve!('File', allowed: ['String'], error_class: SecurityError)
# => SecurityError: Unsafe or unknown class resolution attempted: "File"
```

## Testing Reference

### Test Coverage Summary

**File**: `spec/lib/better_together/safe_class_resolver_spec.rb` (225 lines)

**Test Categories:**
1. **Nil/blank input handling** (lines 9-23): Returns nil for nil, empty, and blank strings
2. **Valid class resolution** (lines 25-57): Resolves classes in allow-list (strings and class objects)
3. **Disallowed class rejection** (lines 59-75): Returns nil for classes not in allow-list
4. **Non-existent class handling** (lines 77-82): Returns nil when class doesn't exist
5. **Security tests** (lines 84-103): Prevents code injection and arbitrary execution
6. **resolve! exception tests** (lines 127-160): Raises errors on resolution failure
7. **Edge cases** (lines 162-225): Handles symbols, leading `::`, mixed allow-lists

### Example Test Patterns

**Testing Allow-List Validation:**
```ruby
RSpec.describe BetterTogether::SafeClassResolver do
  describe '.resolve' do
    it 'resolves class when in allow-list' do
      result = described_class.resolve('String', allowed: [String])
      expect(result).to eq(String)
    end
    
    it 'returns nil when not in allow-list' do
      result = described_class.resolve('String', allowed: [Integer])
      expect(result).to be_nil
    end
  end
end
```

**Testing Security Properties:**
```ruby
describe 'security' do
  it 'prevents arbitrary code execution' do
    malicious = 'File.delete("/tmp/test")'
    result = described_class.resolve(malicious, allowed: [String])
    expect(result).to be_nil
  end
end
```

**Testing Exception Behavior:**
```ruby
describe '.resolve!' do
  it 'raises when class not in allow-list' do
    expect {
      described_class.resolve!('File', allowed: ['String'])
    }.to raise_error(ArgumentError, /Disallowed class/)
  end
end
```

## Migration Guide

### Replacing Unsafe Constantize

**Before (Vulnerable):**
```ruby
class MyController < ApplicationController
  def show
    # ❌ UNSAFE: Brakeman warning
    @model_class = params[:type].constantize
    @records = @model_class.all
  end
end
```

**After (Safe):**
```ruby
class MyController < ApplicationController
  ALLOWED_TYPES = [
    'BetterTogether::Person',
    'BetterTogether::Community'
  ]
  
  def show
    # ✅ SAFE: Allow-list validated
    @model_class = BetterTogether::SafeClassResolver.resolve(
      params[:type],
      allowed: ALLOWED_TYPES
    )
    
    if @model_class
      @records = @model_class.all
    else
      render_error "Invalid type"
    end
  end
end
```

### Replacing Safe Constantize

**Before (Still Risky):**
```ruby
# safe_constantize doesn't prevent malicious input
klass = params[:class_name].safe_constantize
klass&.find(id)
```

**After (Truly Safe):**
```ruby
klass = BetterTogether::SafeClassResolver.resolve(
  params[:class_name],
  allowed: ALLOWED_CLASSES
)
klass&.find(id)
```

## Troubleshooting

### Common Issues

#### 1. Class Name Not Resolving Despite Being in Allow-List

**Problem**: `resolve` returns `nil` even though class is in allow-list

**Diagnosis:**
```ruby
class_name = "BetterTogether::Person"
allowed = ["Person"]  # ❌ Missing namespace

result = SafeClassResolver.resolve(class_name, allowed: allowed)
# => nil
```

**Solution**: Use fully qualified class names in allow-list
```ruby
allowed = ["BetterTogether::Person"]  # ✅ Full namespace
result = SafeClassResolver.resolve(class_name, allowed: allowed)
# => BetterTogether::Person
```

#### 2. Leading `::` Causing Resolution Failure

**Problem**: Class with leading `::` not matching allow-list

**Diagnosis:**
```ruby
result = SafeClassResolver.resolve(
  "::BetterTogether::Person",
  allowed: ["BetterTogether::Person"]  # No leading ::
)
# => nil (lib version) or normalized (service version)
```

**Solution**: Use consistent naming or rely on service module normalization
```ruby
# Option 1: Match exactly (lib version)
allowed = ["::BetterTogether::Person"]

# Option 2: Use service module (auto-normalizes)
# app/services version strips leading ::
```

#### 3. Allow-List with Class vs String Mismatch

**Problem**: Allow-list has class constant but query uses string

**Diagnosis:**
```ruby
allowed = [BetterTogether::Person]  # Class constant
result = SafeClassResolver.resolve("Person", allowed: allowed)
# => nil (needs full class name)
```

**Solution**: Use full class name matching allow-list
```ruby
result = SafeClassResolver.resolve(
  "BetterTogether::Person",  # Match full name
  allowed: [BetterTogether::Person]
)
# => BetterTogether::Person
```

## Future Enhancements

### Planned Improvements

1. **Concern-based registration**: Standardize self-registering allow-lists via concerns
2. **Audit logging**: Track all resolution attempts for security monitoring
3. **Allow-list composition**: Combine multiple allow-lists with union/intersection operations
4. **Performance optimization**: Cache resolved classes to avoid repeated lookups
5. **Developer warnings**: Detect potential allow-list gaps during development

### Extension Points

**Custom Resolution Logic:**
```ruby
# Future: Support custom validators
SafeClassResolver.resolve(
  params[:type],
  allowed: ALLOWED_TYPES,
  validator: ->(klass) { klass.respond_to?(:shareable?) }
)
```

**Hierarchical Allow-Lists:**
```ruby
# Future: Allow all subclasses of base class
SafeClassResolver.resolve(
  params[:type],
  allowed: { parent: BetterTogether::Content::Block, include_subclasses: true }
)
```

---

## Integration Points

### Dependencies
- **Ruby**: `const_get` for safe constant resolution
- **Rails**: `safe_constantize` (lib version only)
- **Brakeman**: Static security scanner this utility satisfies

### Used By
- **BetterTogether::Categorizable** - Dynamic category class resolution
- **BetterTogether::RolesHelper** - Resource type filtering
- **BetterTogether::ResourcePermissionsHelper** - Permission checks
- **BetterTogether::WizardStepsController** - Form class lookup
- **BetterTogether::Metrics::TrackShareJob** - Shareable type validation

### Security Audits
- ✅ Brakeman UnsafeReflection warnings eliminated
- ✅ Code injection prevention validated via security tests
- ✅ Allow-list pattern enforced across 7+ integration points

---

*This reference documentation provides comprehensive guidance for safely resolving class names from untrusted input, following Better Together Community Engine's security-first principles and eliminating reflection-based vulnerabilities.*
