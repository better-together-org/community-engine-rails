# Platform Theme Settings

Platform managers set the main look of a platform without writing CSS. Open the platform, choose Edit, then the Appearance tab.

## What you can set

- Colours: primary, text on primary buttons, accent, dark accent, page background, section band background, body text, link, navigation background and text, footer background and links. Use six digit hex values such as `#243542`. Leave a field empty to keep the default.
- Font: system sans-serif, Tahoma, Georgia or monospace.
- Corner radius: square, small, medium or large.
- Images: the site logo, a header banner and a favicon.

## Built-in themes

Five balanced themes ship with the platform: Neutral, Warm, Cool, High contrast and Dark. Every colour pair in every theme meets WCAG AA (4.5 to 1 for text, 3 to 1 for the accent outline). Pairs that also reach AAA (7 to 1) are marked "AAA" in the contrast list.

Pick a theme in the Theme dropdown. The live preview below it shows a navigation bar, headings, body text, links, primary and secondary buttons, a badge, an alert, a card, a form input and a footer in that theme. Nothing is saved yet. A status line states which theme is being previewed.

- Apply theme copies the previewed theme into the fields, where you can still adjust it.
- Reset puts the fields and preview back to the saved values.
- Clear all theme fields empties every colour, font and radius field. Save to return to the default theme.

Edit any colour, font or radius field by hand and the preview and the contrast list update at once.

## Light and dark mode

Every theme has a light and a dark colour set. Visitors see a three-way toggle in the navigation bar: Auto (follows the device setting `prefers-color-scheme`), Light and Dark. The choice is remembered in the browser (localStorage) and a cookie, so the server renders the right mode on the first paint. The mode is applied with Bootstrap 5.3 `data-bs-theme` on the `html` element by a small inline script in the page head.

In the Appearance tab, under Light and dark mode:

- Dark mode: enable or disable it. When disabled the toggle is hidden and the site is light only.
- Default for new visitors: Auto, Light or Dark.
- Dark colours: Derive automatically builds a dark set from your light colours so every pair still meets AA. Set my own shows a dark field for each colour; any you leave empty are derived.
- The built-in themes ship with hand-checked dark sets. Every pair meets AA in both modes.
- Dark colours apply only to colours that have a light value.
- The preview has a Light and Dark switch, and the contrast list shows the mode being previewed. A summary line reports pairs below AA for both modes.
- Dark mode logo: optional. Shown in dark mode instead of the site logo; the site logo is the fallback.

The toggle is keyboard operable, has a labelled group, 44 pixel targets and announces the new mode. Reset returns the form to the saved values.

Host app note: gem views use only the `--bts-*` custom properties and Bootstrap variables. A host `theme.scss` that hardcodes colours will not follow dark mode; switch those to `var(--bs-body-bg)`, `var(--bs-body-color)` and the `--bts-*` tokens, or set Dark mode to Disabled.

![Light and dark mode settings](../screenshots/desktop/platform_theme_modes_settings.png)

![Dark preview](../screenshots/desktop/platform_theme_preview_mode_dark.png)

![Toggle, light](../screenshots/desktop/platform_site_color_mode_light.png)

![Toggle, dark](../screenshots/desktop/platform_site_color_mode_dark.png)

## Contrast checks

Below the colour fields, each important pair shows its contrast ratio as you type: button text on primary, navigation text on its background, footer links on the footer, body text and links on the page and band colours, and the accent. Normal text needs at least 4.5 to 1 (WCAG AA). A pair under that shows a red "Below AA" warning. The warning does not block saving, so you can decide, but low contrast text is hard to read for many people.

## The site logo

The logo field edits the logo of the platform's own community, the same logo shown in the navigation bar. There is no second copy to keep in sync.

## How it is applied

Saved values become CSS custom properties (`--bts-primary`, `--bts-font`, `--bts-radius`, and so on) in a style element placed before the platform Css block. Because the Css block comes after, custom CSS still wins and stays the escape hatch for anything the theme fields do not cover. The header banner is exposed as `--bts-header-banner`; layouts decide where to show it.

![Theme dropdown open](../screenshots/desktop/platform_theme_dropdown.png)

![Warm theme previewed](../screenshots/desktop/platform_theme_preview_warm.png)

![Dark theme previewed](../screenshots/desktop/platform_theme_preview_dark.png)

![Low contrast warning](../screenshots/desktop/platform_theme_low_contrast.png)

![Theme settings flow](../diagrams/exports/png/platform_theme_settings_flow.png)
