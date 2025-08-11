# Host Dashboard Extensions

The host dashboard provided by Better Together includes a hook for host applications to display custom resources.

To add your own content, create the following partial in your host application:

```
app/views/better_together/host_dashboard/_host_app_resources.html.erb
```

Any markup placed in this partial will be rendered near the top of the dashboard. This is useful for linking to admin areas or providing host-specific information.

Example:

```erb
<!-- host app: app/views/better_together/host_dashboard/_host_app_resources.html.erb -->
<div class="row my-4">
  <div class="col">
    <%= link_to 'My Custom Admin Area', my_custom_path, class: 'btn btn-primary' %>
  </div>
</div>
```

If the partial is absent, the dashboard simply skips this section.

## Customizing Resource Listings

Host applications can also adjust the resources displayed on the dashboard by modifying the resource definition arrays exposed by the controller. Each definition hash expects a `:model` and `:url_helper` with optional `:collection` and `:count` lambdas.

Append a new resource:

```ruby
# config/initializers/host_dashboard_resources.rb
BetterTogether::HostDashboardController::ROOT_RESOURCE_DEFINITIONS << {
  model: -> { MyResource },
  url_helper: -> { :my_resource_path },
  collection: -> { MyResource.limit(5) }, # optional
  count: -> { MyResource.count }          # optional
}
```

Or replace the entire list:

```ruby
BetterTogether::HostDashboardController::CONTENT_RESOURCE_DEFINITIONS = [
  { model: -> { MyOtherResource }, url_helper: -> { :my_other_resource_path } }
]
```

When `:collection` or `:count` are omitted, the dashboard falls back to the model's latest three records and total count.
