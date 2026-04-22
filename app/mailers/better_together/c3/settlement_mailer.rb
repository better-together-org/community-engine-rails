# frozen_string_literal: true

module BetterTogether
  module C3
    # Delivers settlement lifecycle emails for C3 Tree Seeds notifications.
    class SettlementMailer < BetterTogether::ApplicationMailer
      # rubocop:todo Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      def settlement_notification(recipient = nil, *_args, settlement: nil, event_type: nil, **kwargs)
        @recipient = recipient || kwargs[:recipient] || params[:recipient]
        @settlement = settlement || kwargs[:settlement] || params[:settlement]
        @event_type = (event_type || kwargs[:event_type] || params[:event_type]).to_sym

        return if @recipient.blank? || @recipient.email.blank? || @settlement.blank?

        self.locale = @recipient.locale if @recipient.respond_to?(:locale)
        self.time_zone = @recipient.time_zone if @recipient.respond_to?(:time_zone)
        @tree_seeds_amount = tree_seeds_amount
        @event_copy = event_copy
        @agreement_url = agreement_url

        mail(to: @recipient.email, subject: subject_for_event)
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

      def tree_seeds_amount
        amount = @settlement.c3_millitokens.to_f / BetterTogether::C3::Token::MILLITOKEN_SCALE
        format('%<amount>.4g', amount: amount)
      end

      def event_copy
        case @event_type
        when :c3_locked
          'Tree Seeds have been reserved for your agreement. They will be released if the agreement is cancelled.'
        when :c3_lock_released
          'Tree Seeds have been returned to your balance.'
        else
          'Tree Seeds have been exchanged. Your balance has been updated.'
        end
      end

      def agreement_url
        BetterTogether::Engine.routes.url_helpers.joatu_agreement_url(@settlement.agreement, locale: locale)
      end

      private

      def subject_for_event
        case @event_type
        when :c3_locked
          I18n.t('better_together.notifications.c3.settlement.locked.title', default: 'Tree Seeds reserved')
        when :c3_lock_released
          I18n.t('better_together.notifications.c3.settlement.released.title',
                 default: 'Tree Seeds reservation released')
        else
          I18n.t('better_together.notifications.c3.settlement.settled.title', default: 'Tree Seeds exchanged')
        end
      end
    end
  end
end
