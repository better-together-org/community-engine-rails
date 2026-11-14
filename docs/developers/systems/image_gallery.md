# Image gallery

`render_image_gallery(images, name, layout: :grid, label: nil)` in `BetterTogether::ImageHelper`
renders a list of image blocks (anything that responds to `#media`) as an accessible gallery.

## Markup

- `section.image-gallery.image-gallery--grid` labelled with `label` (default `name`).
- `ul.image-gallery__list > li.image-gallery__item > figure.image-gallery__figure`.
- `img.image-gallery__image` uses the image's own `alt_text` and falls back to `name`.
- `figcaption.image-gallery__caption` appears only when the image has a caption or attribution
  (attribution links to `attribution_url` when set).
- Images are `loading="lazy"`, `decoding="async"`, carry `width` and `height` from the blob metadata
  (analysed after upload) and a `srcset` of 480 and 960 pixel variants where the format is variable.
  SVG and GIF load as-is.

## Layouts

- `:grid` (default) is a CSS grid, so DOM order equals visual order.
- `:masonry` is opt-in. It attaches `better_together--masonry` to the list, with
  `data-better-together--masonry-item-selector-value=".image-gallery__item"`. The controller
  destroys the Masonry instance in `disconnect()`.

An unknown layout falls back to `:grid`. The two-argument call `render_image_gallery(images, name)` still works.

## Tests

`spec/helpers/better_together/image_helper_render_image_gallery_spec.rb`, `spec/dom_contracts/image_gallery_spec.rb`,
`spec/features/better_together/image_gallery_accessibility_spec.rb` (axe) and
`spec/docs_screenshots/better_together/image_gallery_spec.rb`. The specs render the helper through a
test-only host partial, `spec/dummy/app/views/better_together/test_support/_gallery.html.erb`.
