# frozen_string_literal: true

# app/jobs/better_together/platform_invitation_mailer_job.rb
module BetterTogether
  # Alows for sending the PlatformInvitationMailer as a background job
  class PlatformInvitationMailerJob < MailerJob
    retry_on Net::OpenTimeout, wait: :polynomially_longer, attempts: 5

    # rubocop:todo Metrics/MethodLength
    def perform(platform_invitation_id) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      platform_invitation = BetterTogether::PlatformInvitation.find(platform_invitation_id)
      platform = platform_invitation.invitable

      # Use the platform's time zone for all time-related operations within this block
      Time.use_zone(platform.time_zone) do
        current_time = Time.zone.now
        valid_from = platform_invitation.valid_from
        valid_until = platform_invitation.valid_until

        # Perform the date comparisons in the platform's time zone
        if valid_from <= current_time && (valid_until.nil? || valid_until > current_time)
          I18n.with_locale(platform_invitation.locale) do
            BetterTogether::PlatformInvitationMailer.invite(platform_invitation).deliver_now
          end
          # Set the last_sent attribute to the current time in the platform's time zone
          platform_invitation.update!(last_sent: current_time)
        else
          Rails.logger.info "Invitation #{platform_invitation_id} is not within the valid period and was not sent."
        end
      end
    end
    # rubocop:enable Metrics/MethodLength
  end
end
