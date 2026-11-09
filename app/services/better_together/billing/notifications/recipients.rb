# frozen_string_literal: true

module BetterTogether
  module Billing
    module Notifications
      # The people an audience means for one thing.
      #
      # Only the thing's own platform is ever looked at: a steward of another platform is never
      # told. The people told are those who may manage billing for the platform (the `manage_platform`
      # permission). The person who just did it is left out (they know), and so is anyone who is not a
      # person with an inbox. Orders sold by a community or person have no platform billing
      # managers to tell; their sellers will be told when community billing exists.
      class Recipients
        # The same permission PlanPolicy asks for, so whoever can manage billing hears about it.
        PERMISSION = 'manage_platform'

        def self.call(...) = new(...).call

        def initialize(audience:, subject:, actor: nil)
          @audience = audience.to_sym
          @subject = subject
          @actor = actor
        end

        def call
          people.compact.uniq(&:id).reject { |person| person.id == actor&.id || person.is_a?(BetterTogether::Robot) }
        end

        private

        attr_reader :audience, :subject, :actor

        def people
          case audience
          when :buyer then [buyer]
          when :holder then [credit_holder]
          when :seller, :operator then managers
          else []
          end
        end

        # The person who paid: the order's buyer, else the payer of the subscription or entitlement it is about.
        def buyer = order&.buyer || term&.payer || entitlement_payer

        # The person whose store credit a lot or account is.
        def credit_holder
          case subject
          when CreditLot then subject.account.holder
          when CreditAccount then subject.holder
          end
        end

        # The payer of an entitlement, who is told when it starts and when it ends.
        def entitlement_payer = (subject.payer if subject.is_a?(Entitlement))

        # The subscription a renewal period or its terms belong to.
        def term
          @term ||= case subject
                    when SubscriptionTerm then subject
                    when SubscriptionPeriod then subject.term
                    end
        end

        # The order a payment, a refund or the order itself belongs to.
        def order
          @order ||= case subject
                     when Order then subject
                     when Payment, OfflinePayment, SubscriptionPeriod then subject.order
                     when Refund then subject.payment.order
                     end
        end

        def managers
          return [] if order&.seller_id.present?

          platform = subject.try(:platform)
          return [] unless platform

          BetterTogether::PersonPlatformMembership.active.includes(:member).where(joinable: platform, role_id: manager_role_ids).map(&:member)
        end

        def manager_role_ids
          BetterTogether::Role.joins(:resource_permissions).where(better_together_resource_permissions: { identifier: PERMISSION }).select(:id)
        end
      end
    end
  end
end
