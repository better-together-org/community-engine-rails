# Community page hooks

The community page (`better_together/communities/show`) renders three small partials a host app can override without copying the whole page. The default markup is the same as before.

| Partial | Locals | Default | Typical host use |
|---|---|---|---|
| `better_together/communities/_header_media` | `community:` | cover (`#cover_community_<id>`) and profile image (`#profile_image_community_<id>`) | show the logo as a tile, or large in place of a missing cover |
| `better_together/communities/_location_line` | `community:` | the named location (`#community-location`) | link the place to its own page |
| `better_together/communities/_about_extra` | `community:` | empty | add a card below the location line |

The header wrapper keeps `#profile_header_community_<id>` whatever a host renders inside it.

## Overriding

Add a partial at the same path in the host app (`app/views/better_together/communities/_about_extra.html.erb`). Declare strict locals with `<%# locals: (community:) -%>`. Keep the ids above so specs and screenshots keep finding their targets.

## Specs and screenshots

- DOM contract: `spec/dom_contracts/community_show_hooks_spec.rb` (default render, and an override replacing only its own partial).
- Screenshots: `spec/docs_screenshots/better_together/community_show_hooks_spec.rb`, output in `docs/screenshots/{desktop,mobile}/community_show_hooks_*`.
