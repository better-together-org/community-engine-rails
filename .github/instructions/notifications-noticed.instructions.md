---
applyTo: "**/*notifier*.rb,**/notifiers/**/*.rb,**/mailers/**/*.rb"
---
# Noticed v3 Notification Patterns

## Architecture: Event vs Notification

Noticed v3 separates two distinct objects:

- **`Noticed::Event`** — one record per notification event. Your notifier class (`class FooNotifier < ApplicationNotifier`) IS the Event subclass. Methods defined directly on the class run in Event context.
- **`Noticed::Notification`** — one record per recipient per event. Methods defined inside `notification_methods do` run in Notification context, where `recipient` is available.

**Critical rule**: `recipient` is ONLY available inside `notification_methods do` blocks, `config.if` lambdas, and delivery method callbacks. Calling `recipient` at the Event class level raises `NameError`.

```ruby
# ❌ WRONG — recipient called at Event level
def locale
  recipient&.locale || I18n.default_locale  # NameError in production
end

# ✅ CORRECT — recipient only inside notification_methods
notification_methods do
  def can_receive_notification?
    recipient.notification_preferences.fetch('alerts', true)
  end
end
```

## ApplicationNotifier Provided Methods

`ApplicationNotifier` provides these to all notifiers — do NOT duplicate them:

### `recipient_has_email?` (notification context)
Standard email guard. Available inside `notification_methods` blocks and `config.if` lambdas:
```ruby
deliver_by :email, mailer: 'MyMailer', method: :notify, params: :email_params,
                   queue: :mailers do |config|
  config.if = -> { recipient_has_email? }
end
```

Implementation: checks `email.present?` and `notification_preferences.fetch('notify_by_email', true)`.

Notifiers with non-standard email eligibility (e.g. checking `user.email`, or requiring a key to be explicitly set rather than defaulting true) define their own override inside `notification_methods`.

### `locale` (event context)
Default: `I18n.locale || I18n.default_locale`. Override in notifiers where a params model carries the recipient's locale:
```ruby
# Override when you have a known params model
def locale
  member&.locale || I18n.locale || I18n.default_locale
end
```

### `locale_for_notification(notification)` (event context)
Returns `notification.recipient&.locale || locale`. Use this in `build_message` so every notification renders in the recipient's preferred language:
```ruby
def build_message(notification)
  I18n.with_locale(locale_for_notification(notification)) do
    { title:, body:, url: review_path }
  end
end
```

## Standard Notifier Structure

```ruby
class FooNotifier < ApplicationNotifier
  # 1. Delivery declarations first
  deliver_by :action_cable, channel: 'BetterTogether::NotificationsChannel',
                            message: :build_message, queue: :notifications
  deliver_by :email, mailer: 'BetterTogether::FooMailer', method: :notify,
                     params: :email_params, queue: :mailers do |config|
    config.if = -> { recipient_has_email? }
  end

  # 2. Required params
  required_param :foo

  # 3. Single notification_methods block (delegate + helpers that need recipient)
  notification_methods do
    delegate :foo, :title, :body, :url, to: :event
    # Only add custom recipient_has_email? here if standard doesn't fit
  end

  # 4. Event-level param accessors
  def foo
    params[:foo] || record
  end

  # 5. Locale (only if you have a params model with locale; otherwise omit — base covers it)
  # def locale = member&.locale || I18n.locale || I18n.default_locale

  # 6. Content methods
  def title
    I18n.with_locale(locale) { I18n.t('...', default: '...') }
  end

  def body
    I18n.with_locale(locale) { I18n.t('...', default: '...') }
  end

  # 7. build_message wraps in per-recipient locale
  def build_message(notification)
    I18n.with_locale(locale_for_notification(notification)) do
      { title:, body:, url: }
    end
  end

  # 8. email_params uses notification.recipient for dynamic recipient
  def email_params(notification)
    { foo:, recipient: notification.recipient }
  end

  # 9. URL helpers
  def url
    BetterTogether::Engine.routes.url_helpers.foo_path(foo, locale:)
  end
end
```

## Method Signature Rules

All `build_message` and `email_params` methods use the named parameter `notification` (no underscore prefix), regardless of whether the body currently uses it:

```ruby
# ✅ Correct — consistent, named
def build_message(notification)  ...  end
def email_params(notification)   ...  end

# ❌ Wrong — inconsistent, misleading
def build_message(_notification) ...  end
def email_params(_notification)  ...  end
```

## notification_methods Block

Each notifier has **at most one** `notification_methods do` block. If content logically splits, merge into one:

```ruby
# ✅ One consolidated block
notification_methods do
  delegate :foo, :title, :body, to: :event

  def can_receive?
    recipient.notification_preferences.fetch('foo_alerts', true)
  end
end

# ❌ Two separate blocks — consolidate these
notification_methods do
  delegate :foo, to: :event
end
# ... other methods ...
notification_methods do
  def can_receive? ...  end
end
```

## email_params: Static vs Dynamic Recipient

**Static (known params model is the recipient)** — pass the params model directly:
```ruby
def email_params(notification)
  { membership:, recipient: member }  # member comes from params
end
```

**Dynamic (recipient varies per notification)** — use `notification.recipient`:
```ruby
def email_params(notification)
  { community:, recipient: notification.recipient, review_url: }
end
```

Use the static form only when the params model and the notification recipient are always the same person (e.g. `member = membership.member`). When multiple stewards or organizers can receive the same event, use `notification.recipient`.

## Locale in build_message

The `locale_for_notification(notification)` wrapper in `build_message` is **required** for all notifiers where `locale` does not already reference a specific params model:

- Omit the wrapper when `locale` uses a params model (`member&.locale`, `person&.locale`, `member_data[:locale]`) — the locale is already recipient-scoped.
- Apply the wrapper for all other notifiers (platform connection, safety report, membership request, etc.) — they default to `I18n.locale` which is the background job's thread locale, not the recipient's preferred language.

```ruby
# Notifier with params-model locale — no wrapper needed
def locale = member&.locale || I18n.locale || I18n.default_locale

def build_message(notification)
  { title:, body:, url: }  # locale already set via member
end

# Notifier without params-model locale — wrapper required
# locale inherited from ApplicationNotifier: I18n.locale || I18n.default_locale

def build_message(notification)
  I18n.with_locale(locale_for_notification(notification)) do
    { title:, body:, url: }  # renders in recipient's language
  end
end
```

## Mailer URL Generation

Always use the engine's route helpers explicitly. Never call bare route helpers in mailers — they resolve to the wrong controller or fail with missing `:id`:

```ruby
# ❌ Wrong — calls bare agreement_url route helper with no arguments
@agreement_url = agreement_url

# ✅ Correct — explicit engine route with the model
private

def agreement_url
  ::BetterTogether::Engine.routes.url_helpers.joatu_agreement_url(
    @settlement.agreement,
    locale: I18n.locale
  )
end
```

The same pattern applies to any URL generated in a mailer that maps to an engine-namespaced resource.

## Testing Notifiers

```ruby
RSpec.describe BetterTogether::FooNotifier do
  let(:person) { create(:better_together_person) }
  let(:notification) { instance_double(Noticed::Notification, recipient: person) }
  let(:notifier) { described_class.new(record: foo, params: { foo: foo }) }

  # Regression: methods must not call bare `recipient` at Event level
  it 'does not raise NameError from bare recipient call' do
    expect { notifier.title }.not_to raise_error
    expect { notifier.build_message(notification) }.not_to raise_error
  end

  # Regression: email_params must use notification.recipient, not bare recipient
  it 'uses notification.recipient in email_params' do
    params = notifier.email_params(notification)
    expect(params[:recipient]).to eq(person)
  end
end
```
