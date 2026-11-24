# frozen_string_literal: true

module BetterTogether
  module Billing
    module PurchaseRequirements
      # Whether a person may buy a dependent purchasable now, given what they already hold and what else is in the same
      # order. With no rules it is open to everyone. With rules it needs any one rule met, plus every rule marked
      # `required`. Answers with what is unmet so the screen can say why. The server decides; a screen only explains.
      class Evaluate
        Result = Data.define(:met, :unmet) do
          alias_method :met?, :met
        end

        def self.call(...) = new(...).call

        # `in_order:` are the other purchasables on the same order (not the dependent itself).
        def initialize(dependent:, person:, in_order: [])
          @dependent = dependent
          @person = person
          @in_order = Array(in_order)
        end

        def call
          rules = Rules.for(dependent)
          return Result.new(met: true, unmet: []) if rules.empty?

          required, optional = rules.partition(&:required)
          unmet = required.reject { |rule| met?(rule) }
          unmet += optional if optional.any? && optional.none? { |rule| met?(rule) }
          Result.new(met: unmet.empty?, unmet:)
        end

        private

        attr_reader :dependent, :person, :in_order

        def met?(rule)
          (rule.holding? && held?(rule)) || (rule.in_order? && ordered?(rule))
        end

        def held?(rule)
          return false if person.blank?
          return rule.prerequisite.held_by?(person) unless rule.kind?

          Plans::Holdings.call(platform: dependent.platform, person:).any?
        end

        def ordered?(rule)
          return in_order.include?(rule.prerequisite) unless rule.kind?

          class_name = PurchaseRequirement::KINDS.fetch(rule.prerequisite_kind)
          in_order.any? { |purchasable| purchasable.instance_of?(class_name.constantize) && !purchasable.extra? }
        end
      end
    end
  end
end
