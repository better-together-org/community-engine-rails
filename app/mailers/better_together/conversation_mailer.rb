# frozen_string_literal: true

module BetterTogether
  # Sends email notifications for conversation activities
  class ConversationMailer < ApplicationMailer
    # rubocop:todo Metrics/AbcSize
    def new_message_notification # rubocop:todo Metrics/MethodLength, Metrics/AbcSize
      @platform = BetterTogether::Platform.find_by(host: true)
      @message = params[:message]
      @conversation = @message.conversation
      @recipient = params[:recipient]
      @sender = @message.sender

      from = t('better_together.conversation_mailer.new_message_notification.from_address',
               from_address: default_params[:from])
      subject = t('better_together.conversation_mailer.new_message_notification.subject')
      if @recipient.show_conversation_details
        if @conversation.title.present?
          subject = t('better_together.conversation_mailer.new_message_notification.subject_with_title',
                      conversation: @conversation.title)
        end
        from = t('better_together.conversation_mailer.new_message_notification.from_address_with_sender',
                 sender_name: @sender.name,
                 from_address: default_params[:from])
      end

      # Override time zone and locale if necessary
      self.locale = @recipient.locale
      self.time_zone = @recipient.time_zone

      mail(to: @recipient.email,
           from:, subject:)
    end
    # rubocop:enable Metrics/AbcSize
  end
end
