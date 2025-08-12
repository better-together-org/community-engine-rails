# SEO

The engine exposes helpers that output common search engine optimisation tags.

## Canonical URL

`seo_meta_tags` includes a canonical `<link>` tag pointing to the current request
URL. You can override the URL by setting a `content_for` block:

```erb
<% content_for :canonical_url, article_url(@article, locale: :en) %>
```

## Hreflang links

Alternate language links are generated for each available locale. Additional
links can be appended using `content_for :hreflang_links` and are merged with the
default set:

```erb
<% content_for :hreflang_links do %>
  <%= tag.link rel: 'alternate', hreflang: 'x-default', href: root_url %>
<% end %>
```

Links supplied via `content_for` are merged with the automatically generated
links rather than replacing them.
