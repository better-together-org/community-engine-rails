# Accessibility Testing

Community Engine uses Capybara feature specs plus axe-core to verify WCAG 2.1 AA behavior on user-facing UI.

Accessibility passes must include a full localization pass for every supported language. A UI change is not considered accessible if it only passes in the default locale.

## Primary Browser Testing Path

- Canonical browser layer: `spec/features`
- JavaScript driver: Selenium Chrome via `spec/support/capybara.rb`
- Accessibility matcher setup: `spec/support/axe.rb`
- Auth and host setup helpers: `spec/support/automatic_test_configuration.rb`, `spec/support/better_together/capybara_feature_helpers.rb`

This project keeps `spec/system` as supplemental coverage only. New Selenium-driven UI coverage should default to `spec/features`.

## When Browser Accessibility Coverage Is Required

Add or update a feature spec when a change affects:

- forms, multi-step flows, or other interactive UI
- inline help text, hints, onboarding, banners, notices, or validation messages
- focus order, keyboard navigation, or live updates
- user-facing moderator or safety workflows
- responsive behavior that changes meaning or access to controls

Request specs remain useful for server behavior, but they are not sufficient for accessibility-sensitive UI work on their own.

## Required Accessibility Assertions

For new or materially changed user-facing interactive flows:

1. Use a Capybara feature spec with `:js`
2. Run the feature flow in each supported locale
3. Run axe against the relevant region with:
   - `:wcag2a`
   - `:wcag2aa`
   - `:wcag21a`
   - `:wcag21aa`
4. Add focused semantic assertions where axe is not enough:
   - labels and `aria-describedby`
   - keyboard access and focus visibility
   - live region or status messaging behavior
   - mobile reflow and visible instructions
5. Confirm translated labels, hints, errors, and statuses render correctly without fallback drift or layout breakage

The supported locale set is defined by `APP_AVAILABLE_LOCALES`. The default Community Engine support set includes `en`, `fr`, `es`, and `uk`.

Example:

```ruby
RSpec.describe 'Example accessibility', :accessibility, :as_user, :js, retry: 0 do
  it 'passes WCAG 2.1 AA checks' do
    visit some_path(locale: I18n.default_locale)

    expect(page).to be_axe_clean
      .within('main')
      .according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)
  end
end
```

## Report-Form Reference

The reporting flow is the current reference implementation for:

- accessible field hints
- explicit help-text associations
- consent guidance
- browser-level accessibility assertions

Reference spec:
- `spec/features/better_together/reports_accessibility_spec.rb`

## Screenshot Support

Documentation screenshots are opt-in and live separately from ordinary feature coverage:

- helper: `spec/support/capybara_screenshot_engine.rb`
- docs-only specs: `spec/docs_screenshots/`
- runner: `bin/docs_screenshots`
- task: `rake docs:screenshots`

Use screenshots for:

- documentation assets
- UX/help-text review
- review evidence for accessibility work

Do not use screenshots as the primary correctness oracle.

## Current Tooling Assessment

- CE Capybara + Selenium feature setup: adopt as-is
- CE axe-core setup: adopt as-is
- CE screenshot-engine branch concepts: adopt with cleanup
- management-tool Selenium screenshot service: adopt with cleanup and integration
- stale documentation references: replace or repair before treating them as policy
