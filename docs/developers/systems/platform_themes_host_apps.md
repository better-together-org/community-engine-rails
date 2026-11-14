# Adding your own themes (host apps and extension gems)

The theme picker on a platform's Appearance tab lists the five built-in themes plus any theme your host app
or an extension gem registers. Registered themes are validated the same way as built-ins, appear in the picker,
are stored as the platform's `preset` and can still be tweaked token by token.

## Option 1: a YAML file in the host app

Create `config/platform_themes.yml` in the host app. It is loaded automatically on boot and after code reloads.
Each key is a theme id (lowercase letters, digits and underscores, starting with a letter; built-in ids cannot be reused).

```yaml
acme_forest:
  name: Acme forest                 # optional label
  description: Deep green on warm white.   # optional
  primary: '#0b3d2e'
  primary_text: '#ffffff'
  accent: '#2f7d5b'
  accent_dark: '#0b3d2e'
  page_bg: '#fffdf8'
  band: '#f1efe6'
  body_text: '#1f2a24'
  link: '#0b3d2e'
  navbar_bg: '#0b3d2e'
  navbar_link: '#ffffff'
  footer_bg: '#1f2a24'
  footer_link: '#ffffff'
  font: system        # system, tahoma, georgia or monospace
  radius: medium      # none, small, medium or large
  dark:               # optional: hand-tuned dark colours (same keys as above, any subset)
    page_bg: '#101a14'
    body_text: '#e8f0ea'
```

All twelve colour tokens are required and must be `#rrggbb`. A bad theme raises `ArgumentError` at boot with the reason.

## Option 2: Ruby

```ruby
# config/initializers/themes.rb (or an engine initializer)
Rails.application.config.to_prepare do
  BetterTogether::PlatformThemeConfig.register_theme('acme_forest', tokens, name: 'Acme forest')
end
```

Use `to_prepare` so the registration survives code reloading in development.

## Dark mode for your themes

Every registered theme gets a dark mode automatically: dark tokens are derived from the light tokens (works for any
theme, no list to maintain) and meet WCAG AA. If your designers want exact dark colours, add `dark:` (YAML) or
`dark: { ... }` (`register_theme`). Colours you list are used as given; any you leave out are still derived.

## Names and translations

If you pass no `name:`/`description:`, the picker uses `better_together.platforms.theme.presets.<id>.name` and
`.description` from your host locale files, and falls back to the humanized id.

## Keep themes accessible

CE does not reject low-contrast host themes, because your brand colours are yours to choose, but the Appearance tab
warns stewards. Enforce AA in your own suite:

```ruby
BetterTogether::PlatformThemeConfig.themes.each_key do |id|
  it "#{id} meets WCAG AA" do
    expect(BetterTogether::PlatformThemeConfig.contrast_failures(id)).to be_empty
  end
end
```

`PlatformThemeConfig.reset_registered_themes!` clears registered themes (for specs).
