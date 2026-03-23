# HTML Assertion Helpers - Quick Reference Guide

## Problem

When testing HTML responses with factory-generated data containing apostrophes or other special characters:

```ruby
# ❌ THIS FAILS
person = create(:person, name: "O'Brien")
get person_path(person)
expect(response.body).to include(person.name)  
# Fails because HTML has "O&#39;Brien" but assertion checks for "O'Brien"
```

## Solution

Use the HTML assertion helpers that properly parse HTML and decode entities:

```ruby
# ✅ THIS WORKS
person = create(:person, name: "O'Brien")
get person_path(person)
expect_html_content(person.name)  # Handles HTML escaping automatically
```

## Available Helper Methods

### Basic Assertions

#### `expect_html_content(text)`
Check if HTML contains text (handles escaping).

```ruby
expect_html_content(person.name)  # Works with "O'Brien"
```

#### `expect_no_html_content(text)`
Check if HTML does NOT contain text.

```ruby
expect_no_html_content(private_user.name)
```

#### `expect_html_contents(*texts)`
Check multiple texts at once (all must be present).

```ruby
expect_html_contents(
  member1.name,
  member2.name,
  member3.name
)
```

#### `expect_no_html_contents(*texts)`
Check that none of the texts are present.

```ruby
expect_no_html_contents(
  private_user1.name,
  private_user2.name
)
```

### Direct Text Access

#### `response_text`
Get plain text from HTML (entities decoded).

```ruby
expect(response_text).to include(person.name)
expect(response_text).to match(/O'Brien/)
```

#### `parsed_response`
Get Nokogiri document for custom queries.

```ruby
members = parsed_response.css('.member')
expect(members.count).to eq(5)
```

### Element-Specific Assertions

#### `expect_element_content(selector, text)`
Check specific element contains text.

```ruby
expect_element_content('.member-name', person.name)
expect_element_content('#user-role', role.name)
```

#### `expect_element_with_text(selector, text)`
Find any element matching selector that contains text.

```ruby
expect_element_with_text('.member-card', person.name)
```

#### `expect_element_without_text(selector, text)`
Verify element doesn't contain text.

```ruby
expect_element_without_text('.member-list', private_user.name)
```

#### `expect_element_count(selector, count)`
Verify number of matching elements.

```ruby
expect_element_count('.member-row', 10)
expect_element_count('.admin-badge', 2)
```

#### `element_texts(selector)`
Get array of text from all matching elements.

```ruby
names = element_texts('.member-name')
expect(names).to include("O'Brien", "D'Angelo")
```

## Common Usage Patterns

### Pattern 1: Basic Content Check

```ruby
# Before (fails with apostrophes)
expect(response.body).to include(person.name)

# After
expect_html_content(person.name)
```

### Pattern 2: Multiple Content Checks

```ruby
# Before
expect(response.body).to include(member1.name)
expect(response.body).to include(member2.name)
expect(response.body).to include(member3.name)

# After
expect_html_contents(
  member1.name,
  member2.name,
  member3.name
)
```

### Pattern 3: Negative Assertions

```ruby
# Before
expect(response.body).not_to include(private_user.name)

# After
expect_no_html_content(private_user.name)
```

### Pattern 4: Element-Specific Checks

```ruby
# Before (risky - might match anywhere)
expect(response.body).to include(person.name)

# After (precise - checks specific element)
expect_element_content('.member-name', person.name)
```

### Pattern 5: Complex Queries

```ruby
# Get all member names and verify
names = element_texts('.member-name')
expect(names).to contain_exactly(
  "O'Brien",
  "D'Angelo",
  "McDonald's"
)

# Count specific elements
expect_element_count('.member-row', members.count)

# Use Nokogiri for complex queries
admin_section = parsed_response.at_css('.admin-section')
expect(admin_section.text).to include("O'Brien")
```

## When to Use Which Method

### Use `expect_html_content()` when:
- ✅ Checking factory-generated names, titles, or content
- ✅ Testing with data that may contain apostrophes or quotes
- ✅ You just need to verify text appears somewhere in response

### Use `expect_element_content()` when:
- ✅ You need to verify text appears in specific element
- ✅ Testing structured data (tables, lists, cards)
- ✅ Preventing false positives from text appearing elsewhere

### Use `response_text` directly when:
- ✅ Using custom RSpec matchers
- ✅ Complex regex matching
- ✅ Need flexibility for unique assertions

### Use `parsed_response` when:
- ✅ Complex Nokogiri queries needed
- ✅ Checking element attributes or structure
- ✅ Need to traverse DOM tree

### DON'T change for:
- ❌ HTML structure checks: `expect(response.body).to include('data-controller=')`
- ❌ Static strings without special chars: `expect(response.body).to include('Submit')`
- ❌ Feature specs already using Capybara matchers

## HTML Escaping Reference

### Characters That Get Escaped

| Character | HTML Entity      | When It Appears          |
|-----------|------------------|--------------------------|
| `'`       | `&#39;` `&apos;` | Apostrophes (O'Brien)   |
| `"`       | `&quot;`         | Quotes (She said "Hi")  |
| `&`       | `&amp;`          | Ampersands (Widgets & Co)|
| `<`       | `&lt;`           | Less than (Price < $10) |
| `>`       | `&gt;`           | Greater than (Age > 18) |

### Why This Matters

```ruby
# In Ruby/Database
person.name = "Patrick O'Brien"

# In HTML Response
<span>Patrick O&#39;Brien</span>

# String Comparison
"Patrick O'Brien" == "Patrick O&#39;Brien"  # false!

# After Nokogiri Parsing
parsed.text  # "Patrick O'Brien"  ✅
```

## Performance

The helpers use memoization for performance:

```ruby
# First call parses HTML and caches
expect_html_content(person.name)

# Subsequent calls in same test use cached version
expect_html_content(role.name)      # Uses cache
expect_html_content(event.name)     # Uses cache
expect_element_count('.members', 5) # Uses cache
```

Cache is automatically cleared after each test.

## Migration Examples

### Example 1: Person Platform Memberships

**Before:**
```ruby
it 'displays member information' do
  get person_platform_memberships_path
  expect(response.body).to include(person.name)
  expect(response.body).to include(role.name)
end
```

**After:**
```ruby
it 'displays member information' do
  get person_platform_memberships_path
  expect_html_contents(person.name, role.name)
end
```

### Example 2: Communities Controller

**Before:**
```ruby
it 'shows all members' do
  get community_members_path(community)
  expect(response.body).to include(first_member.name)
  expect(response.body).to include(second_member.name)
end
```

**After:**
```ruby
it 'shows all members' do
  get community_members_path(community)
  expect_html_contents(first_member.name, second_member.name)
end

# Or more precise:
it 'shows all members' do
  get community_members_path(community)
  expect_element_with_text('.member-card', first_member.name)
  expect_element_with_text('.member-card', second_member.name)
end
```

### Example 3: Feature Spec (Capybara)

**Before:**
```ruby
# In feature specs, use Capybara matchers instead
within('select[name="conversation[participant_ids][]"]') do
  expect(page).not_to have_content(user2.person.name)
end
```

**After:**
```ruby
# Feature specs don't need these helpers - use Capybara
expect(page).not_to have_select(
  'conversation[participant_ids][]',
  with_options: [user2.person.name]
)
```

## Testing the Helpers

Full test suite available at `spec/support/html_assertion_helpers_spec.rb`:

```bash
bin/dc-run bundle exec rspec spec/support/html_assertion_helpers_spec.rb
```

Integration test at `spec/requests/html_assertion_helpers_integration_spec.rb`.

## Additional Resources

- Full documentation: `spec/support/html_assertion_helpers.rb`
- Test suite: `spec/support/html_assertion_helpers_spec.rb`
- Integration tests: `spec/requests/html_assertion_helpers_integration_spec.rb`
- Implementation inventory: `tmp/spec_assertion_improvements_inventory.txt`
