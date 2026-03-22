# Help Banners (Reusable)

Simple, consistent help messages you can drop into any page.

## Quick Use

- Basic (uses translation):

  ```erb
  <%= help_banner id: 'joatu-offers-index',
                  i18n_key: 'better_together.joatu.help.offers.index' %>
  ```

- Custom text:

  ```erb
  <%= help_banner id: 'my-custom-help', text: 'This is a short help message.' %>
  ```

- With a screenshot:

  ```erb
  <%= help_banner id: 'with-screenshot',
                  i18n_key: 'better_together.joatu.help.requests.form',
                  image_path: 'ui/requests-help.png' %>
  ```

- Custom icon/color:

  ```erb
  <%= help_banner id: 'with-icon',
                  i18n_key: 'better_together.joatu.help.agreements.show',
                  icon: 'fas fa-question-circle text-primary' %>
  ```

## What It Does

- Shows a friendly help message with an info icon.
- “Hide this help” button persists preference server‑side per user.
- When hidden, shows a small “Show help again” link.
- Accessible defaults: `role="status"`, Bootstrap alert layout.

## How It Works

- View helper:
  - `help_banner(id:, i18n_key: nil, text: nil, **opts)` calls a shared partial.
- Partial:
  - `app/views/better_together/shared/_help_banner.html.erb`
  - Reads preference using `help_banner_hidden?(id)`.
  - Posts to `hide_help_banner_path` via Stimulus to save preference.
  - Renders a “Show help again” button posting to `show_help_banner_path` when hidden.
- Stimulus controller:
  - `app/javascript/controllers/better_together/help_banner_controller.js`
  - Handles click → POST hide and hides immediately.

## Options

- `id` (required): unique identifier per page/section (e.g., `joatu-offers-index`).
- `i18n_key`: translation key for message.
- `default`: default fallback text when i18n missing.
- `text`: direct string when not using i18n.
- `icon`: CSS classes, default `fas fa-info-circle`.
- `classes`: wrapper classes, default `alert alert-info d-flex align-items-start`.
- `role`: ARIA role, default `status`.
- `image_path`: optional screenshot/image.
- `render_show_again`: boolean (default true).
- `hide_url`, `show_url`: override endpoints if needed.

## Notes

- Preferences are stored in `Person.preferences['help_banners'][id]`.
- Banners render server‑side hidden when preference is set.
- You can add translations in `config/locales/*` under `better_together.joatu.help.*`.

