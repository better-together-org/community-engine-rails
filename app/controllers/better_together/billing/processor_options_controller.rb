# frozen_string_literal: true

module BetterTogether
  module Billing
    # Option lists for the processor-backed selects of the plan form (products, prices,
    # currencies, intervals), fetched live from the platform's own processor account and
    # served as plain JSON for the SlimSelect controller.
    #
    # Only {value, text} rows leave this controller, as plain text; a vendor object is
    # never returned. The processor and the kind are checked against what is configured, so
    # nothing a request names is resolved or called unless it was offered. Results are
    # cached for a minute per platform, so typing in the box does not become an API call
    # per keystroke.
    class ProcessorOptionsController < ApplicationController
      include OwnerScoped

      after_action :verify_authorized

      CACHE_TTL = 1.minute
      MAX_SEARCH = 100
      MAX_LIMIT = 50
      DEFAULT_LIMIT = 25
      UNAVAILABLE_HEADER = 'X-Billing-Lookup-Error'

      def index
        authorize BetterTogether::Billing::Plan, :lookup?
        return head(:unprocessable_content) unless adapter && kind_allowed?

        render json: option_rows
      end

      private

      # The rescue lives here, not on #index, so it can never swallow the authorization
      # failure raised above it.
      def option_rows
        options.map(&:to_select_option)
      rescue ProcessorAdapter::LookupError => e
        unavailable(e)
      rescue StandardError => e
        BetterTogether.report_error(e, context: { processor: processor, kind: kind })
        unavailable(e)
      end

      # The processors this platform has configured; anything else is refused.
      def processor
        @processor ||= BetterTogether::Billing::Configuration.processors_for(billing_owner).map(&:to_s).find { |name| name == params[:processor].to_s }
      end

      def context
        @context ||= BetterTogether::Billing::Configuration.context_for(billing_owner, processor) if processor
      end

      def adapter
        @adapter ||= BetterTogether::Billing.processor_adapter(processor) if processor
      end

      def kind = params[:kind].to_s

      def kind_allowed?
        served_by_adapter? || core_kind?
      end

      def served_by_adapter?
        adapter.supports?(:lookups) && adapter.lookup_kinds.map(&:to_s).include?(kind)
      end

      def core_kind? = %w[currencies intervals].include?(kind)

      def search = params[:search].to_s.strip.first(MAX_SEARCH)

      def limit
        requested = params[:limit].presence&.to_i
        requested ? requested.clamp(1, MAX_LIMIT) : DEFAULT_LIMIT
      end

      # Only the narrowing keys a lookup understands, each a short string.
      def scope = params.fetch(:scope, {}).permit(:product).to_h.transform_values { |value| value.to_s.first(200) }

      def options
        Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) { fetch_options }
      end

      def fetch_options
        rows = served_by_adapter? ? adapter.lookup(context:, kind:, search:, scope:, limit:) : []
        rows = core_rows if rows.empty? && core_kind?
        limit_to_what_core_accepts(rows).first(limit)
      end

      # Currencies and intervals are checked by Plan's own validations, so offer only those.
      def limit_to_what_core_accepts(rows)
        accepted = { 'currencies' => Plan::SUPPORTED_CURRENCY_CODES, 'intervals' => Plan::BILLING_INTERVALS }[kind]
        accepted ? rows.select { |row| accepted.include?(row.value.to_s) } : rows
      end

      # The fallback list when the processor has no lookup of its own for the kind.
      def core_rows
        values = kind == 'currencies' ? (adapter.supported_currencies || Plan::SUPPORTED_CURRENCY_CODES) : (adapter.supported_intervals || Plan::BILLING_INTERVALS)
        values.map { |value| LookupOption.new(value:, text: value) }
              .select { |row| search.blank? || row.text.downcase.include?(search.downcase) }
      end

      def cache_key
        ['billing-lookup', billing_owner.id, processor, kind, scope.sort.to_h, search.downcase, limit]
      end

      # The steward's picker shows a message; the cause is logged, never sent.
      def unavailable(error)
        Rails.logger.warn("[billing] lookup unavailable for #{processor} #{kind}: #{error.class}")
        response.set_header(UNAVAILABLE_HEADER, 'unavailable')
        []
      end
    end
  end
end
