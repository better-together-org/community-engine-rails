# Finding records located in a place

`Geography::Locatable::One` (events, event occurrences) now provides a `located_in(place)` scope. A host model
that keeps its own `has_one :location` (a `LocatableLocation`) can include
`Geography::Locatable::LocatedIn` to get the same scope without becoming Mappable.

```ruby
BetterTogether::Event.located_in(settlement)
```

A record is in a place when:

- its explicit location is the place itself, or
- its location is an address or building that `HierarchyResolutionJob` has already placed within the place
  (that placement is a `LocatableLocation` row of the address pointing at the settlement).

The scope is built with Arel in `Geography::LocationQueries`. It only narrows a relation, so privacy still comes from
the policy scope you start from; apply `located_in` to a policy scope, never to `Model.all` for a viewer.

## Inheriting a place

`inherit_location_from(:association)` makes a record with no location row of its own count through the record it
belongs to (a post takes its community's place). A free-text location is still the record's own, so it does not
inherit. `effective_location` returns the own place, else the inherited one.

```ruby
class Post
  include BetterTogether::Geography::Locatable::LocatedIn
  inherit_location_from :community
end
```

The inheritance target must itself respond to `located_in`.
