---
applyTo: "**/*.erb,**/*.rb,**/helpers/*.rb"
---
# Action View & Helper Guidelines (Better Together Community Engine)

These conventions match our actual stack: **Rails 7.1+**, **PostgreSQL (pgcrypto/PostGIS)**, **Hotwire (Turbo + Stimulus)**, **Bootstrap 5.3**, **Font Awesome 6**, **Action Text/Trix**, **Mobility + I18n**, **Sidekiq/Redis**, **Noticed**, **Active Record Encryption**, and strict **CSP**.
Use this when creating/updating helpers or view code.

---

## 0. Core Principles

- **Presentation only**: Helpers format/prepare data for views; keep business logic in POROs/services.
- **Accessibility first** (WCAG AA/AAA): semantic HTML, ARIA, keyboard nav, visible focus, prefers-reduced-motion.
- **Internationalization everywhere**: No hard‑coded copy. All strings via `I18n.t`. Attribute text via **Mobility**.
- **Authorization-aware UI**: Never render an action the user can’t perform. Wrap links/buttons in policy checks.
- **Security by default**: Escape output, sanitize user HTML, respect CSP nonces.
- **Performance smart**: Preload data in controllers, cache fragments, avoid N+1s in helpers.

---

## 1. Organization & Namespacing

- Helpers live in `app/helpers/`. Group by concern (`FormattingHelper`, `NavigationHelper`, `TurboHelper`, etc.).
- Engine-specific helpers can be under `BetterTogether::` namespace inside the engine.
- Keep helpers small. If a helper is large/complex, consider a ViewComponent or Stimulus-driven partial.

```ruby
# app/helpers/navigation_helper.rb
module NavigationHelper
  def nav_link_to(name, path, icon: nil, **opts)
    active  = current_page?(path)
    classes = ["nav-link", opts.delete(:class), ("active" if active)].compact.join(" ")
    body    = safe_join([icon && icon_tag(icon), name].compact, " ")
    link_to(body, path, class: classes, **opts)
  end
end
```

---

## 2. Internationalization (I18n) & Mobility

### Rules
- Wrap all UI strings: `t(".label")` inside views; `t("better_together.shared.some_key")` for shared keys.
- Use `l(object, format: :long)` (localized dates/times) rather than manual `strftime`.
- For model attributes translated with Mobility, use `model.attribute` which returns the value in `I18n.locale`.
- When you need a specific locale (e.g., email previews): `I18n.with_locale(user.locale) { ... }`.
- Don’t concatenate translated strings with HTML; use interpolation placeholders (`%{name}`) and `html: true` only if needed.

```ruby
# Helper example to ensure fallback but show missing key visibly in dev
def t_present(key, **opts)
  I18n.t(key, **opts)
rescue I18n::MissingTranslationData
  Rails.env.production? ? "" : "[missing #{key}]"
end
```

---

## 3. Formatting Helpers

### Dates & Times
- Use `Time.current` (zone aware) not `Time.now`.
- Relative times: `time_ago_in_words`, `distance_of_time_in_words` wrapped in `<abbr title="full time">` for accessibility.

```ruby
def relative_time(time)
  return "" unless time
  content_tag(:abbr, time_ago_in_words(time), title: l(time, format: :long))
end
```

### Numbers
- `number_to_currency`, `number_to_percentage`, `number_to_human_size`, `number_with_delimiter`, `number_with_precision`.
- Currency symbol/format from I18n.

### Text
- `truncate`, `pluralize`, `excerpt`, `word_wrap`, `simple_format`.
- For rich text (Action Text), use `record.body` and `to_plain_text` for indexing/search.

### Privacy Display
- Use `privacy_display_value(entity)` for consistent, translated privacy level display across the application.
- This helper automatically looks up the proper translation from `attributes.privacy_list` and falls back to humanized values.
- Supports all privacy levels: `public`, `private`, `community`, `unlisted`.

```ruby
# Instead of: entity.privacy.humanize or entity.privacy.capitalize
<%= privacy_display_value(@event) %>      # "Public" / "Público" / "Public"
<%= privacy_display_value(@community) %>  # "Private" / "Privado" / "Privé"

# Works in badges too (automatically used)
<%= privacy_badge(@entity) %>  # Uses privacy_display_value internally
```

---

## 4. Navigation & Link Helpers

- `link_to` for GET navigation; `button_to` with proper HTTP verbs for mutations.
- Always check authorization:

```ruby
def policy_link_to(record, action, name = nil, path = nil, **opts)
  return unless policy(record).public_send("#{action}?")
  link_to(name || record.to_s, path || record, **opts)
end
```

### External Link Indicator (.trix-content)
- Use CSS pseudo-element for global rule (see §12), or wrap link text with an icon helper:
  
```ruby
def external_link_to(name, url, **opts)
  body = safe_join([name, external_icon], " ")
  link_to(body, url, rel: "noopener noreferrer", target: "_blank", **opts)
end

def external_icon
  content_tag(:i, "", class: "fa-solid fa-arrow-up-right-from-square", aria: { hidden: true })
end
```

---

## 5. Asset & Tag Helpers

- Prefer `image_tag`, `asset_path`, `favicon_link_tag` over raw tags.
- Provide descriptive `alt` text for images (or `alt: ""` if purely decorative).
- For icons, centralize with `icon_tag(name, style: "solid")`.

```ruby
def icon_tag(name, style: "solid", **opts)
  classes = ["fa-#{style}", "fa-#{name}", opts.delete(:class)].compact.join(" ")
  content_tag(:i, "", class: classes, aria: { hidden: true })
end
```

- Use `tag`, `content_tag`, `safe_join`, `capture` rather than string concatenation.

---

## 6. Forms

- Use `form_with model:` unless embedding fields inside another form (`fields_for` or tag helpers only).
- Bootstrap classes for consistency; always provide `<label>` (or `aria-label`) and error feedback.

```erb
<%= form_with model: @page do |f| %>
  <div class="mb-3">
    <%= f.label :title, class: "form-label" %>
    <%= f.text_field :title, class: "form-control", required: true %>
    <%= form_error_text(@page, :title) %>
  </div>
<% end %>
```

```ruby
def form_error_text(record, attr)
  return unless record.errors[attr].present?
  content_tag(:div, record.errors[attr].to_sentence, class: "invalid-feedback d-block")
end
```

- Avoid `local: true` when you want Turbo to handle submissions/streams.

---

## 7. Hotwire Helpers (Turbo/Stimulus)

- `turbo_frame_tag`, `turbo_stream_from`, `turbo_stream` blocks instead of manual tags.
- Provide tiny helpers for common frame patterns.

```ruby
def frame_for(record, &block)
  turbo_frame_tag(dom_id(record)) { capture(&block) }
end
```

- Use Stimulus data attributes (`data-controller`, `data-action`) instead of inline JS.

---

## 8. Layout & Content Slots

- Use `content_for` and `yield` for layout regions (`:page_title`, `:sidebar`, etc.).
- `capture` for assembling complex HTML parts in helpers.
- `safe_join(array, separator)` for joining safe strings.

```erb
<% content_for :page_title, t(".title") %>
<%= tag.main class: "container" do %>
  <%= yield %>
<% end %>
```

---

## 9. Security & CSP

- Escape by default: `h`, `sanitize`, `strip_tags`.
- Inline JS must include `nonce: true`. Use `javascript_csp_nonce` when needed.
- Use `json_escape` for embedding JSON safely.

```erb
<%= javascript_tag nonce: true do %>
  const data = <%= raw json_escape(@model.to_json) %>;
<% end %>
```

- Never disable CSP or use `unsafe-inline` as a shortcut.

---

## 10. Performance & Caching

- `cache` blocks for fragments. Key by record + locale + current_user role if the output varies.
- Russian doll caching for lists.
- Heavy work? Move to background job, memoize, or controller.

```erb
<% cache [@product, I18n.locale] do %>
  <%= render @product %>
<% end %>
```

---

## 11. Testing Helpers

- Test complex helpers in isolation.
- Verify escaping, I18n, and policy checks.
- Test different locales/roles to ensure correct output.
- Watch for performance regressions (Benchmark if hot path).

---

## 12. External Link CSS (Reference Option)

If handled via CSS in `.trix-content` instead of helper logic:

```scss
.trix-content a[href]:not([href*="newcomernavigatornl.ca"]):not([href^="mailto:"]):not([href^="tel:"]):not([href$=".pdf"])::after {
  font-family: "Font Awesome 6 Free";
  font-weight: 900;
  content: "\\f35d"; // external-link icon
  margin-left: 0.3rem;
  aria-hidden: true;
}
```

---

## 13. Don’ts

- ❌ Heavy queries or remote calls in helpers.
- ❌ Inline JS event handlers (`onclick`, etc.).
- ❌ Rendering unauthorized actions.
- ❌ Returning raw strings without marking safe/escaping.

---

## 14. Handy Built-ins (Reminder)

- HTML: `tag`, `content_tag`, `safe_join`, `capture`, `sanitize`, `strip_tags`
- Links/Assets: `link_to`, `button_to`, `mail_to`, `image_tag`, `asset_path`
- Hotwire: `turbo_frame_tag`, `turbo_stream_from`, `turbo_stream`
- Numbers/Dates: `number_to_*`, `time_ago_in_words`, `distance_of_time_in_words`, `l`
- Text: `pluralize`, `truncate`, `word_wrap`, `simple_format`
- Perf: `cache`, `expires_in`
- I18n: `t`, `l`
