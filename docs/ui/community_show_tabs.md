# Community page tabs

The community page (`/c/:slug`) uses the `better_together--tabs` Stimulus controller, as the event page does.

- Tabs and panes are paired by id: each `#<name>-tab` has `aria-controls="<name>"`, and each `.tab-pane#<name>` is labelled by its tab.
- Tabs: About, Contact (only with contact details), Members, Roles and permissions, Pages, Posts, Events.
- Posts and Events embed `posts_path(community_id:)` and `events_path(community_id:)` in lazy `turbo-frame`s (`community-posts`, `community-events`, `target="_top"`). The indexes are frame-aware; see `FramedIndex`.
- A URL hash naming a pane (`/c/rac#events`) selects the tab and the controller resets the scroll to the top. Back and Forward do not switch tabs.
- The map sits beside the tabs when the community has building pins or is located at a geocoded place (`Geography::Locatable::LocationMapPoints`).
- The description is rendered in a `div` so rich text is valid HTML.

DOM ids: `community-tabbed-section`, `communityTabs`, `community-description`, `community-location`, `community-map`.
