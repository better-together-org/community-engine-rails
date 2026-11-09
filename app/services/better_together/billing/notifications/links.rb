# frozen_string_literal: true

module BetterTogether
  module Billing
    module Notifications
      # Where a notification leads. A buyer goes to their order; a steward to the sale, or to the
      # screen where the thing they are told about is managed. Always an in-app address, never a
      # processor's or a payee's.
      module Links
        module_function

        def order_of(record)
          case record
          when Order then record
          when Payment, OfflinePayment then record.order
          when Refund then record.payment.order
          end
        end

        def path(notifier, record)
          routes = BetterTogether::Engine.routes.url_helpers
          locale = notifier.locale
          order = order_of(record)
          return routes.billing_order_path(order, locale:) if order && notifier.audience == :buyer
          return routes.billing_sale_path(order, locale:) if order

          steward_path(routes, record, locale)
        end

        def steward_path(routes, record, locale)
          case record
          when ProcessorSetting then routes.billing_processor_settings_path(locale:)
          else routes.billing_plans_path(locale:)
          end
        end
      end
    end
  end
end
