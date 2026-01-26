# Mailer HTML Assertion Helpers Reference

## Overview

The `MailerHtmlHelpers` module provides HTML-aware assertions for mailer specs that properly handle HTML entity escaping. These helpers solve the common flaky test problem where factory-generated content with special characters (apostrophes, quotes) causes test failures.

## The Problem

When testing mailer content with factory-generated data:

```ruby
# ❌ FLAKY - Fails when event.name contains apostrophes
let(:event) { create(:event) }  # Name might be "O'Brien's Event"

it 'includes event name' do
  expect(mail.body.encoded).to include(event.name)
  # Fails: HTML has "O&#39;Brien&#39;s Event" but assertion checks "O'Brien's Event"
end
```

## The Solution

Use HTML-aware helpers that parse and decode HTML entities:

```ruby
# ✅ ROBUST - Handles HTML escaping automatically
it 'includes event name' do
  expect_mail_html_content(mail, event.name)
  # Works: Nokogiri parses HTML and decodes entities before comparison
end
```

## Available Helpers

### Basic Assertions

#### `expect_mail_html_content(mail, text)`
Check if mailer HTML includes text (handles entity escaping).

```ruby
expect_mail_html_content(mail, event.name)
expect_mail_html_content(mail, person.name)
```

#### `expect_no_mail_html_content(mail, text)`
Check if mailer HTML does NOT include text.

```ruby
expect_no_mail_html_content(mail, private_info)
```

#### `expect_mail_html_contents(mail, *texts)`
Check multiple texts at once (all must be present).

```ruby
expect_mail_html_contents(mail, event.name, location.name, person.name)
```

#### `expect_no_mail_html_contents(mail, *texts)`
Check that none of the texts are present.

```ruby
expect_no_mail_html_contents(mail, secret1, secret2)
```

### Advanced Helpers

#### `mail_text(mail)`
Get decoded plain text from HTML mail.

```ruby
text = mail_text(mail)
expect(text).to include("O'Brien")  # Works with apostrophes
```

#### `parsed_mail_body(mail)`
Get Nokogiri document for custom queries.

```ruby
doc = parsed_mail_body(mail)
headings = doc.css('h1, h2, h3')
```

#### `expect_mail_element_content(mail, selector, text)`
Check specific element text by CSS selector.

```ruby
expect_mail_element_content(mail, '.event-name', event.name)
expect_mail_element_content(mail, 'h1', 'Welcome')
```

#### `expect_mail_element_count(mail, selector, count)`
Verify element count.

```ruby
expect_mail_element_count(mail, '.attendee', 5)
expect_mail_element_count(mail, 'p', 3)
```

#### `mail_element_texts(mail, selector)`
Get array of text from matching elements.

```ruby
names = mail_element_texts(mail, '.member-name')
expect(names).to include(person.name)
```

## When to Use

### ✅ Use These Helpers For:
- Factory-generated names, titles, descriptions
- Any content with apostrophes, quotes, or special characters
- Testing with Faker-generated data
- Mailer specs checking text content in HTML emails

### ❌ Don't Use For:
- HTML structure checks: `expect(mail.body.encoded).to include('data-controller=')`
- Static text without escaping issues: `expect(mail.body.encoded).to include('Welcome')`
- Regex patterns on structure: `expect(mail.body.encoded).to match(/<div class=/)`

## Common Use Cases

### Testing Event Mailers
```ruby
RSpec.describe EventMailer do
  let(:event) { create(:event, :with_location) }
  let(:mail) { described_class.with(event: event).event_reminder }

  it 'includes event details' do
    expect_mail_html_contents(mail, 
      event.name, 
      event.location_display_name,
      person.name
    )
  end
end
```

### Testing With Conditional Content
```ruby
it 'includes location if present' do
  if event.location?
    expect_mail_html_content(mail, event.location_display_name)
  end
end
```

### Testing Multiple Entities
```ruby
it 'includes all participant names' do
  participants = create_list(:person, 3)
  names = participants.map(&:name)
  expect_mail_html_contents(mail, *names)
end
```

### Element-Specific Checks
```ruby
it 'shows event name in heading' do
  expect_mail_element_content(mail, 'h1', event.name)
end

it 'lists all attendees' do
  expect_mail_element_count(mail, '.attendee', 5)
  attendee_names = mail_element_texts(mail, '.attendee-name')
  expect(attendee_names).to match_array(expected_names)
end
```

## Implementation Details

### How It Works
1. Parses mail HTML body using Nokogiri
2. Extracts text content (automatically decodes HTML entities)
3. Compares decoded text against expected values
4. Caches parsed document per mail object for performance

### HTML Entity Decoding
- `'` (apostrophe) → `&#39;` or `&apos;`
- `"` (quote) → `&#34;` or `&quot;`
- `&` (ampersand) → `&amp;`
- `<` (less than) → `&lt;`
- `>` (greater than) → `&gt;`

All automatically handled by Nokogiri's text extraction.

## Migration Guide

### Before
```ruby
it 'renders the body with event details' do
  expect(mail.body.encoded).to include(event.name)
  expect(mail.body.encoded).to include(event.location_display_name)
end
```

### After
```ruby
it 'renders the body with event details' do
  expect_mail_html_contents(mail, event.name, event.location_display_name)
  # Or individual checks:
  # expect_mail_html_content(mail, event.name)
  # expect_mail_html_content(mail, event.location_display_name)
end
```

## Related Documentation

- [HTML Assertion Helpers Reference](html_assertion_helpers_reference.md) - For request specs
- [Testing Architecture Standards](../AGENTS.md#testing-architecture-standards) - Project testing guidelines

## Source Code

Location: [`spec/support/mailer_html_helpers.rb`](../../spec/support/mailer_html_helpers.rb)

Automatically included in all mailer specs via RSpec configuration.
