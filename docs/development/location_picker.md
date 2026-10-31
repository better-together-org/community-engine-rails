# Shared location picker

Any form whose record has a `has_one :location` (a `LocatableLocation`) can render one picker:

```erb
<%= render 'better_together/locations/picker', form: form, record: record %>
```

Optional locals `label:` and `hint:` override the default text. Ids come from the record's `param_key`:
`<key>_location_picker`, `<key>_location_picker_hint`, `<key>_location_picker_error`, `<key>_location_new_address`.

The record must permit `location_attributes` (see `Geography::Locatable::One`), and the "new address" panel only shows
when the person may create addresses.

## Lookup endpoint

`GET /:locale/locations/available` (`LocationsController#available`), signed-in people only.

- `location_type` (optional): a class from `Geography::Placeable.included_in_models`. Returns up to 25 `{value, text}`
  rows with bare ids. Without it, searches every type and returns up to 5 per type as `ClassName:id`.
- `search`: cut to 100 characters, passed to `LocatableLocation.available_<type>_for`, which applies each type's
  privacy rules for the current person.
- An unknown type returns 422. A new Placeable type needs only a matching `available_<type>_for` method.

Moved from `EventsController#available_locations`, which is removed.
