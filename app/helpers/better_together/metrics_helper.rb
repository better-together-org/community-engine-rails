module BetterTogether
  module MetricsHelper
    def metrics_body_tag(body_class: '', &block)
      options = {
        class: body_class,
        data: {
          controller: 'better_together--metrics',
          link_metrics_url: metrics_link_clicks_path(locale: I18n.locale),
          page_view_url: metrics_page_views_path(locale: I18n.locale),
          viewable_type: metric_viewable_type,
          viewable_id: metric_viewable_id
        }
      }
      content_tag(:body, options, &block)
    end
  end
end

