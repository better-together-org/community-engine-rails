# frozen_string_literal: true

module BetterTogether
  module Billing
    # Host platform operators look into billing webhook events that failed or were dead-lettered,
    # and retry them. Pages show states, counts and reasons only: the payload and the error
    # text are encrypted and never rendered.
    class EventsController < ApplicationController
      include OwnerScoped

      PER_PAGE = 50
      STATES = %w[problems failed dead_lettered pending replayed all].freeze

      before_action :set_event, only: %i[show replay]
      after_action :verify_authorized

      def index
        authorize BetterTogether::Billing::Event
        @state = STATES.include?(params[:state]) ? params[:state] : 'problems'
        @alert_summary = platform_events.operator_alert_summary
        @events = filtered(platform_events).newest_first.page(params[:page]).per(PER_PAGE)
      end

      def show
        authorize @event
      end

      # Repeating the request is harmless: once replayed the event is no longer a problem, so it is refused.
      def replay
        authorize @event
        result = BetterTogether::Billing::ReplayEvent.call(billing_event: @event, requested_by: current_user.person)
        if result.enqueued
          redirect_to billing_event_path(@event, locale: I18n.locale), notice: t('better_together.billing.events.replayed')
        else
          fallback = t('better_together.billing.events.refused.other')
          redirect_to billing_event_path(@event, locale: I18n.locale),
                      alert: t("better_together.billing.events.refused.#{result.reason}", default: fallback)
        end
      end

      private

      # The pages work before any payment method is on, so an operator can reach them during an incident.
      def billing_available? = BetterTogether::Billing.configurable?(billing_owner)

      def platform_events = policy_scope(BetterTogether::Billing::Event)

      def set_event
        @event = platform_events.find(params[:id])
      end

      def filtered(scope)
        case @state
        when 'problems' then scope.problematic
        when 'all' then scope
        else scope.where(processing_status: @state)
        end
      end
    end
  end
end
