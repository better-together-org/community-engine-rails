# frozen_string_literal: true

module BetterTogether
  module Billing
    module PurchaseRequirements
      # The rules that apply to a dependent purchasable: the ones stored for it, and, until PS-6 converts add-ons,
      # the ones its add-on links imply. An add-on that extends named plans needs one of them (held or in the order);
      # an add-on with no links extends every primary plan, which is the kind `plan`. Nothing is written: the implied
      # rules are built in memory so existing add-ons behave exactly as before.
      class Rules
        def self.for(dependent) = new(dependent).call

        def initialize(dependent)
          @dependent = dependent
        end

        def call
          stored = PurchaseRequirement.for_dependent(dependent).to_a
          stored.presence || implied
        end

        private

        attr_reader :dependent

        def implied
          return [] unless dependent.respond_to?(:add_on?) && dependent.add_on?

          links = dependent.target_links.includes(:plan).to_a
          return [build(prerequisite_kind: 'plan')] if links.empty?

          links.map { |link| build(prerequisite: link.plan) }
        end

        def build(**target)
          PurchaseRequirement.new(platform_id: dependent.platform_id, dependent:, met_by: 'either', **target)
        end
      end
    end
  end
end
