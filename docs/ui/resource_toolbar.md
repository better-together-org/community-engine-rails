# Resource Toolbar

A shared partial for rendering edit, view, and destroy buttons for a resource.

## Usage

```
<%= render 'shared/resource_toolbar',
           back_to_list_path: posts_path,
           edit_path: edit_post_path(@post),
           view_path: post_path(@post),
           destroy_path: post_path(@post),
           destroy_confirm: t('globals.confirm_delete'),
           edit_aria_label: 'Edit Post',
           view_aria_label: 'View Post',
           destroy_aria_label: 'Delete Post' do %>
  <%= link_to 'Publish', publish_post_path(@post), class: 'btn btn-outline-success btn-sm' %>
<% end %>
```

## Locals

- `back_to_list_path` – link for a back action (optional)
- `edit_path` – link for the edit action (optional)
- `view_path` – link for the view action (optional)
- `destroy_path` – link for the destroy action (optional)
- `destroy_confirm` – confirmation text for destroy (defaults to `t('globals.confirm_delete')`)
- `edit_aria_label`, `view_aria_label`, `destroy_aria_label` – ARIA labels for accessibility.

Buttons render only when the corresponding path is provided. Defaults use the global translations for button text and ARIA labels.

### Block Content

When a block is given, its content renders in a separate, right-aligned toolbar section, allowing additional actions to be appended without mixing with the primary actions.
