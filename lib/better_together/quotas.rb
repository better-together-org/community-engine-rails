# frozen_string_literal: true

module BetterTogether
  # Usage ledger facade for the quota framework (Phase 5a, shadow mode). `owner:` is
  # always caller-computed, never resolved internally: a ledger row's `subject`
  # (e.g. an Attachment, for idempotency) and the owner-resolution target (its
  # *owning record*) are different values. check! is hardcoded permissive this
  # phase; reserve!/settle!/reverse! raise on a bug, caught non-fatally per call site.
  module Quotas
    class NonReversibleQuotaError < StandardError; end

    class << self
      # Convenience resolution entry point, equivalent to calling OwnerResolver
      # directly, resolving from `subject` when present, else from `actor`.
      def attribute(subject: nil, actor: nil, **)
        OwnerResolver.resolve(subject || actor)
      end

      # Always permissive this phase. Takes the same keyword shape reserve!/settle!
      # do so a future enforcement phase can swap this implementation without
      # touching call sites.
      # rubocop:todo Naming/PredicateMethod
      # rubocop:todo Lint/UnusedMethodArgument
      def check!(type:, owner:, amount:, subject: nil, actor: nil)
        true
      end
      # rubocop:enable Lint/UnusedMethodArgument
      # rubocop:enable Naming/PredicateMethod

      # rubocop:todo Metrics/ParameterLists
      # rubocop:todo Metrics/MethodLength
      # rubocop:todo Metrics/AbcSize
      def reserve!(type:, owner:, amount:, idempotency_key:, subject: nil, actor: nil, ttl: 5.minutes)
        type_class = Type.find(type)
        quota = find_or_build_quota(type_class, owner)
        period_key = current_period_key(type_class)

        reservation = QuotaReservation.find_or_create_by!(idempotency_key:) do |r|
          r.quota = quota
          r.quota_type = type.to_s
          r.amount = amount
          r.period_key = period_key
          r.subject = subject
          r.actor = actor
          r.owner = owner
          r.expires_at = ttl.from_now
        end

        QuotaBalance.recalculate!(quota, period_key)
        reservation
      end
      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Metrics/ParameterLists

      # rubocop:todo Metrics/ParameterLists
      # rubocop:todo Metrics/MethodLength
      # rubocop:todo Metrics/AbcSize
      def settle!(type:, owner:, amount:, idempotency_key:, subject: nil, actor: nil, event: 'settle')
        type_class = Type.find(type)
        return if subject && !type_class.counts_toward_quota?(subject)

        quota = find_or_build_quota(type_class, owner)
        period_key = current_period_key(type_class)

        usage = QuotaUsage.find_or_create_by!(idempotency_key:) do |u|
          u.quota = quota
          u.quota_type = type.to_s
          u.amount = amount
          u.period_key = period_key
          u.subject = subject
          u.actor = actor
          u.owner = owner
          u.event = event
        end

        QuotaBalance.recalculate!(quota, period_key)
        usage
      end
      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Metrics/ParameterLists

      # rubocop:todo Metrics/ParameterLists
      def reverse!(type:, owner:, amount:, idempotency_key:, subject: nil, actor: nil)
        # rubocop:enable Metrics/ParameterLists
        type_class = Type.find(type)
        raise NonReversibleQuotaError, "#{type} is not reversible" unless type_class.reversible?

        settle!(
          type:, owner:, amount: -amount.abs, idempotency_key:, subject:, actor:, event: 'reverse'
        )
      end

      private

      def find_or_build_quota(type_class, owner)
        Quota.find_or_create_by!(owner:, quota_type: type_class.key) do |q|
          q.limit = type_class.default_limit(owner)
          q.period = type_class.period
        end
      end

      def current_period_key(type_class)
        case type_class.period.to_s
        when 'cumulative' then 'cumulative'
        when 'monthly' then Time.current.strftime('%Y-%m')
        when 'daily' then Time.current.strftime('%Y-%m-%d')
        else raise ArgumentError, "unknown period #{type_class.period}"
        end
      end
    end
  end
end
