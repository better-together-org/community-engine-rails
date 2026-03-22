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
