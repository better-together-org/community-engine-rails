# frozen_string_literal: true

module BetterTogether
  module Billing
    module Plans
      # What a person is to a platform, for plans limited to an audience (member pricing, extra entitlements for subscribers).
      #
      # A member holds a live entitlement from a plan that gives a membership role. A subscriber holds a live entitlement that
      # comes from a subscription. What a person holds is what Entitlements::ForPerson finds: given to them, or paid for by them.
      # A visitor, or someone who is neither, qualifies for no limited plan.
      class Audience
        def self.call(...) = new(...).call

        Result = Struct.new(:member, :subscriber, keyword_init: true)

        def initialize(platform:, person:)
          @platform = platform
          @person = person
        end

        def call
          return Result.new(member: false, subscriber: false) unless person && platform

          Result.new(member: member?, subscriber: subscriber?)
        end

        private

        attr_reader :platform, :person

        def live = @live ||= Entitlements::ForPerson.call(platform:, person:).live

        def member?
          live.where(plan_id: PlanGrant.where(kind: 'membership_role').select(:plan_id)).exists?
        end

        def subscriber? = live.where.not(pay_subscription_id: nil).exists?
      end
    end
  end
end
