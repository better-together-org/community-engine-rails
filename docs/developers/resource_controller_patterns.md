## ResourceController & FriendlyResourceController patterns

This document explains how `ResourceController` and `FriendlyResourceController` (which inherits from it) centralize common controller behavior for CRUD resources in the Better Together engine, including how permitted attributes are resolved.

Key points

- Resource controllers should set `resource_class` to the model they manage. The base `ResourceController` provides `resource_params` which calls `resource_class.permitted_attributes` to produce a strong-parameters list.
- If your model defines `self.permitted_attributes` on the model (recommended), the base controller will automatically use that list when permitting params. This avoids duplication and centralizes permitted attribute definitions.
- For ad-hoc controllers that do not inherit from `ResourceController` (for example, controller actions that are not full CRUD or need custom param handling), call `Model.permitted_attributes` directly when building permit lists.

Example: model-level permitted attributes composition

```ruby
class BetterTogether::Message < ApplicationRecord
  def self.permitted_attributes
    %i[id sender_id content _destroy]
  end
end

class BetterTogether::Conversation < ApplicationRecord
  def self.permitted_attributes
    [ :title, { participant_ids: [] }, { messages_attributes: BetterTogether::Message.permitted_attributes } ]
  end
end
```

Flow diagram

```mermaid
flowchart TD
  A[HTTP request params] --> B[Controller resource_params]
  B --> C{Does controller inherit ResourceController?}
  C -- Yes --> D[resource_class.permitted_attributes]
  C -- No --> E[Call Model.permitted_attributes manually]
  D & E --> F[params.require(...).permit(...)]
  F --> G[Model.new/Model.update]
  G --> H[Model validations & save]
```

When to add `self.permitted_attributes` to a model

- New models or models used in forms that accept nested attributes should expose a `self.permitted_attributes` class method.
- Prefer composing nested attributes using other models' permitted attributes rather than repeating nested keys inline.

Testing note

- Controllers inheriting from `ResourceController` do not need to implement `*_params` methods unless special handling is required. For request/controller/feature specs you can rely on model-level permitted attributes to validate parameter handling.
