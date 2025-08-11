# Resource Toolbar

A shared partial for rendering edit, preview, and destroy buttons for a resource.

## Usage

```
<%= render 'shared/resource_toolbar',
           edit_path: edit_post_path(@post),
           preview_path: preview_post_path(@post),
           destroy_path: post_path(@post),
           destroy_confirm: t('globals.confirm_delete'),
           edit_aria_label: 'Edit Post',
           preview_aria_label: 'Preview Post',
           destroy_aria_label: 'Delete Post' %>
```

## Locals

- `edit_path` – link for the edit action (optional)
- `preview_path` – link for the preview action (optional)
- `destroy_path` – link for the destroy action (optional)
- `destroy_confirm` – confirmation text for destroy (defaults to `t('globals.confirm_delete')`)
- `edit_aria_label`, `preview_aria_label`, `destroy_aria_label` – ARIA labels for accessibility.

Buttons render only when the corresponding path is provided. Defaults use the global translations for button text and ARIA labels.
