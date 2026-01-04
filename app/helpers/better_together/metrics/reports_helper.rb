# frozen_string_literal: true

module BetterTogether
  module Metrics
    module ReportsHelper # rubocop:todo Style/Documentation
      def metrics_tab_styles
        {
          pageviews: { icon: 'fas fa-chart-line', accent: 'bt-tab-accent--primary' },
          linkclicks: { icon: 'fas fa-mouse-pointer', accent: 'bt-tab-accent--success' },
          downloads: { icon: 'fas fa-download', accent: 'bt-tab-accent--neutral' },
          shares: { icon: 'fas fa-share-alt', accent: 'bt-tab-accent--warning' },
          linkchecker: { icon: 'fas fa-link', accent: 'bt-tab-accent--danger' }
        }
      end
    end
  end
end
