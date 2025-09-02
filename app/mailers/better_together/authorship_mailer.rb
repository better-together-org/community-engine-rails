# frozen_string_literal: true

module BetterTogether
  # Sends email notifications for page authorship changes
  class AuthorshipMailer < ApplicationMailer
    # rubocop:todo Metrics/PerceivedComplexity
    # rubocop:todo Metrics/MethodLength
    def authorship_changed_notification # rubocop:todo Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
      @platform = BetterTogether::Platform.find_by(host: true)
      @page = params[:page]
      @recipient = params[:recipient]
      @action = params[:action]
      @actor_name = params[:actor_name]
      @actor_name ||= BetterTogether::Person.find_by(id: params[:actor_id])&.name if params[:actor_id]

      subject = if @action == 'removed'
                  if @actor_name.present?
                    t('better_together.authorship_mailer.authorship_changed_notification.subject_removed_by',
                      page: @page.title, actor_name: @actor_name)
                  else
                    t('better_together.authorship_mailer.authorship_changed_notification.subject_removed',
                      page: @page.title)
                  end
                elsif @actor_name.present?
                  t('better_together.authorship_mailer.authorship_changed_notification.subject_added_by',
                    page: @page.title, actor_name: @actor_name)
                else
                  t('better_together.authorship_mailer.authorship_changed_notification.subject_added',
                    page: @page.title)
                end

      # Respect locale and time zone preferences
      self.locale = @recipient.locale
      self.time_zone = @recipient.time_zone

      mail(to: @recipient.email, subject:)
    end
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/PerceivedComplexity
  end
end
