# frozen_string_literal: true

module BetterTogether
  module Billing
    module Products
      # Moves what was sold as a one-time plan or an add-on plan to a product with one price, then removes the plan.
      # (docs/billing/purchasable_split_plan.md, PS-6.)
      #
      # For each such plan: a product (the same name, description, seller, listing and tax category, until used) and one price
      # (the same amount and currency); its grants, entitlements and agreement requirements move to the product; the lines of
      # past orders now point at the price; blocks that offered the plan offer the price; and what an add-on extended becomes
      # purchase requirements on the product ("holding or ordering" a plan, or any plan when it named none).
      #
      # Everything runs in one transaction with counts compared before and after, so a mismatch leaves nothing changed.
      # A plan a subscription still points at is left alone and reported. Safe to run again: with nothing left to convert it
      # does nothing. `dry_run: true` does the work, reports what it would have done and rolls it back.
      class ConvertPlans # rubocop:disable Metrics/ClassLength
        class Mismatch < StandardError; end

        Result = Data.define(:converted, :skipped, :requirements, :line_items, :entitlements, :grants, :dry_run)

        COUNTS = %i[line_items entitlements grants].freeze

        def self.call(...) = new(...).call

        def initialize(dry_run: false)
          @dry_run = dry_run
          @moved = { line_items: 0, entitlements: 0, grants: 0 }
        end

        # The table the old add-on links lived in. The model is gone with the add-on code, so this is built only when a move
        # needs it (a class whose table is gone would trip anything that walks every model).
        def self.link_class
          @link_class ||= Class.new(ApplicationRecord) do
            def self.name = 'BetterTogether::Billing::Products::ConvertPlans::Link'

            self.table_name = 'better_together_billing_plan_add_ons'
            belongs_to :plan, class_name: 'BetterTogether::Billing::Plan'
          end
        end

        def link = self.class.link_class

        def call
          unless legacy?
            return Result.new(converted: 0, skipped: [], requirements: 0, line_items: 0, entitlements: 0, grants: 0,
                              dry_run: @dry_run)
          end

          result = nil
          Plan.transaction do
            result = convert_all
            raise ActiveRecord::Rollback if @dry_run
          end
          result
        end

        private

        def legacy? = Plan.column_names.include?('add_on') && ApplicationRecord.connection.table_exists?('better_together_billing_plan_add_ons')

        def convert_all # rubocop:disable Metrics/AbcSize
          plans = candidates.to_a
          held, convertible = plans.partition { |plan| subscribed?(plan) }
          before = counts_for(convertible)
          requirements = 0
          mapping = convertible.to_h { |plan| [plan, make_product(plan)] }
          mapping.each do |plan, (product, price)|
            move_references(plan, product, price)
            requirements += make_requirements(plan, product, mapping)
          end
          repoint_stored_requirements(mapping)
          mapping.each_key { |plan| remove(plan) }
          verify!(before, convertible)
          Result.new(converted: convertible.size, skipped: held.map(&:id), requirements:, **@moved, dry_run: @dry_run)
        end

        # Plans sold once: an add-on, or one with the one-time interval.
        def candidates = Plan.where(add_on: true).or(Plan.where(billing_interval: 'one_time')).order(:created_at)

        def subscribed?(plan) = SubscriptionTerm.where(plan_id: plan.id).or(SubscriptionTerm.where(pending_plan_id: plan.id)).exists?

        def counts_for(plans)
          ids = plans.map(&:id)
          { line_items: LineItem.where(purchasable_type: Plan.name, purchasable_id: ids).count,
            entitlements: Entitlement.where(plan_id: ids).count, grants: PlanGrant.where(plan_id: ids).count }
        end

        def product_attributes(plan)
          { platform_id: plan.platform_id, seller: plan.seller, identifier: free_identifier(plan), active: plan.active,
            listed: plan.listed, restricted_to_members: plan.restricted_to_members,
            restricted_to_subscribers: plan.restricted_to_subscribers, tax_category_id: plan.tax_category_id, lifetime: 'until_used' }
        end

        def make_product(plan) # rubocop:disable Metrics/AbcSize
          product = Product.new(product_attributes(plan))
          copy_text(plan, product)
          product.save!
          price = product.prices.create!(platform_id: plan.platform_id, amount_cents: plan.amount_cents, currency: plan.currency,
                                         active: plan.active)
          [product, price]
        end

        # The plan's identifier, unless a product of this seller already has it.
        def free_identifier(plan)
          scope = Product.where(platform_id: plan.platform_id, seller_type: plan.seller_type, seller_id: plan.seller_id)
          taken = scope.pluck(:identifier)
          return plan.identifier unless taken.include?(plan.identifier)

          candidate = "#{plan.identifier}-plan"
          candidate = "#{candidate}-#{SecureRandom.hex(2)}" while taken.include?(candidate)
          candidate
        end

        def copy_text(plan, product)
          I18n.available_locales.each do |locale|
            Mobility.with_locale(locale) do
              { name: :name, description: :description, summary: :participant_summary }.each do |target, source|
                value = plan.public_send(source, locale:, fallback: false)
                product.public_send(:"#{target}=", value) if value.present?
              end
            end
          end
        end

        def move_references(plan, product, price) # rubocop:disable Metrics/AbcSize
          @moved[:grants] += PlanGrant.where(plan_id: plan.id).update_all(plan_id: nil, product_id: product.id)
          @moved[:entitlements] += Entitlement.where(plan_id: plan.id).update_all(plan_id: nil, product_id: product.id)
          @moved[:line_items] += LineItem.where(purchasable_type: Plan.name, purchasable_id: plan.id)
                                         .update_all(purchasable_type: Price.name, purchasable_id: price.id)
          AgreementRequirement.where(target_type: Plan.name, target_id: plan.id).update_all(target_type: Product.name, target_id: product.id)
          repoint_blocks(plan, price)
        end

        # A block that offered the plan offers its price, so a page keeps its button.
        def repoint_blocks(plan, price)
          BetterTogether::Content::PlanButtonBlock.find_each do |block|
            next unless block.plan_id == plan.id

            block.update_columns(content_data: block.content_data.merge('plan_id' => '', 'price_id' => price.id)) # rubocop:disable Rails/SkipsModelValidations
          end
        end

        # What the add-on extended: one rule per plan it named, or any plan when it named none. Rules a steward already wrote win.
        def make_requirements(plan, product, mapping) # rubocop:disable Metrics/AbcSize
          return 0 unless plan.add_on?
          return 0 if PurchaseRequirement.where(dependent: plan).exists?

          links = link.where(add_on_id: plan.id).includes(:plan).to_a
          targets = links.empty? ? [{ prerequisite_kind: 'plan' }] : links.map { |link| { prerequisite: prerequisite_for(link.plan, mapping) } }
          targets.each { |target| PurchaseRequirement.create!(platform_id: plan.platform_id, dependent: product, met_by: 'either', **target) }
          targets.size
        end

        # A prerequisite that was itself a one-time plan is now a product.
        def prerequisite_for(plan, mapping) = mapping.find { |converted, _| converted.id == plan.id }&.last&.first || plan

        # Rules already written about a converted plan now name its product.
        def repoint_stored_requirements(mapping)
          mapping.each do |plan, (product, _price)|
            PurchaseRequirement.where(dependent_type: Plan.name, dependent_id: plan.id).update_all(dependent_type: Product.name,
                                                                                                   dependent_id: product.id)
            PurchaseRequirement.where(prerequisite_type: Plan.name, prerequisite_id: plan.id)
                               .update_all(prerequisite_type: Product.name, prerequisite_id: product.id)
          end
        end

        def remove(plan)
          link.where(plan_id: plan.id).or(link.where(add_on_id: plan.id)).delete_all
          plan.reload.destroy!
        end

        def verify!(before, converted)
          after = counts_for(converted)
          raise Mismatch, "plans still referenced after the move: #{after}" if after.values.any?(&:positive?)

          COUNTS.each do |key|
            raise Mismatch, "#{key}: expected #{before[key]} moved, moved #{@moved[key]}" unless before[key] == @moved[key]
          end
        end
      end
    end
  end
end
