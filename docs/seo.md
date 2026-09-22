# SEO

## Meta Descriptions

- Each high-traffic page should set a concise, unique `content_for :meta_description`.
- Use the `set_meta_description` helper with translation keys under `meta.descriptions`.
- Keep descriptions under 160 characters and include relevant keywords.
- Example:

```erb
<% set_meta_description('communities.show', community_name: @community.name, platform_name: host_platform.name) %>
```

## Best Practices

- Translate descriptions using `config/locales/*` to support internationalization.
- Prefer dynamic values (e.g., community or conversation names) to ensure uniqueness.
- Review descriptions regularly to avoid duplication and improve click-through rates.
