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
          linkchecker: { icon: 'fas fa-link', accent: 'bt-tab-accent--danger' },
          searchqueries: { icon: 'fas fa-search', accent: 'bt-tab-accent--info' },
          searchhealth: { icon: 'fas fa-heart-pulse', accent: 'bt-tab-accent--warning' },
          users: { icon: 'fas fa-users', accent: 'bt-tab-accent--secondary' },
          billing: { icon: 'fas fa-receipt', accent: 'bt-tab-accent--success' }
        }
      end

      # Whether the person may see the billing tab: the same permission the billing charts and reports ask for.
      def billing_metrics_visible?
        BetterTogether::Metrics::BillingReportPolicy.new(current_user, %i[metrics billing_report]).index?
      end

      # The currencies the platform has sold in and the owners of those sales, for the billing filters.
      def billing_filter_options(platform)
        orders = BetterTogether::Billing::Order.for_platform(platform).where(status: BetterTogether::Billing::TaxReport::SALE_STATUSES)
        { currencies: orders.distinct.order(:currency).pluck(:currency), owners: billing_owner_options(orders) }
      end

      private

      # "All", the platform's own sales, and each seller with sales. A seller is only loaded when its type may sell.
      def billing_owner_options(orders) # rubocop:disable Metrics/AbcSize
        options = [[t('better_together.metrics.reports.billing.owner_all'), 'all'],
                   [t('better_together.metrics.reports.billing.owner_platform'), 'platform']]
        sellers = orders.where.not(seller_id: nil).distinct.pluck(:seller_type, :seller_id)
        sellers.group_by(&:first).each do |type, pairs|
          next unless BetterTogether::Billing::SellerScoped.assignable_types.include?(type)

          type.constantize.where(id: pairs.map(&:last)).find_each do |seller|
            options << [seller.try(:name).presence || seller.to_s, "#{type}:#{seller.id}"]
          end
        end
        options
      end
    end
  end
end
