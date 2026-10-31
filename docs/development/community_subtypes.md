# Community subtypes

A host app can add its own kinds of community (a legislature, a party, a committee) as STI subclasses of
`BetterTogether::Community`, and scope roles and permissions to each kind.

```ruby
class PartyCommunity < BetterTogether::Community
  include BetterTogether::CommunitySubtype
end
```

Including `BetterTogether::CommunitySubtype`:

- **Registers the class as a resource type.** `BetterTogether::Resourceful.register_resource_class` adds it to the
  list that `Role` and `ResourcePermission` validate `resource_type` against, and that the role and permission
  pickers offer. A role scoped to `PartyCommunity` is never offered for ordinary communities, because the pickers
  match `resource_type` exactly.
- **Keeps the subtype a Community** to routes, forms and policies (`model_name` and `policy_class` come from
  `Community`), and defines a named `<Subtype>Policy` next to the class, because invitation-token authorization
  finds a policy by class name.
- **Uses the community role set** for the default member role (`community_member`, scoped to the STI base class).
- **Names the role tab** with `community_subtype_label`: the `better_together.community_subtypes.<underscored
  class name>` translation, falling back to the humanized class name. Override the class method to change it.

Hosts that scope roles to a type that is not a Community subtype call
`BetterTogether::Resourceful.register_resource_class('MyApp::Thing', label: -> { 'Things' })` directly.

`BetterTogether::Resourceful.allowed_resource_classes` returns the core list plus everything registered; use it
instead of `RESOURCE_CLASSES` when a list must include host types.
