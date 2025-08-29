# frozen_string_literal: true

module BetterTogether
  # Handles managing conversations
  class ConversationsController < ApplicationController # rubocop:todo Metrics/ClassLength
    include BetterTogether::NotificationReadable

    before_action :authenticate_user!
    before_action :disallow_robots
    before_action :set_conversations, only: %i[index new show]
    before_action :set_conversation, only: %i[show update leave_conversation]
    after_action :verify_authorized

    layout 'better_together/conversation', only: %i[show]

    helper_method :available_participants

    def index
      authorize @conversations
    end

    def new
      @conversation = Conversation.new
      authorize @conversation
    end

    def create # rubocop:todo Metrics/MethodLength, Metrics/AbcSize
      @conversation = Conversation.new(conversation_params.merge(creator: helpers.current_person))

      authorize @conversation

      if @conversation.save
        @conversation.participants << helpers.current_person

        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to @conversation }
        end
      else
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.update(
              'form_errors',
              partial: 'layouts/better_together/errors',
              locals: { object: @conversation }
            )
          end
          format.html { render :new }
        end
      end
    end

    def update # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      authorize @conversation
      ActiveRecord::Base.transaction do # rubocop:todo Metrics/BlockLength
        if @conversation.update(conversation_params)
          @messages = @conversation.messages.with_all_rich_text.includes(sender: [:string_translations])
                                   .order(:created_at)
          @message = @conversation.messages.build

          is_current_user_in_conversation = @conversation.participant_ids.include?(helpers.current_person.id)

          turbo_stream_response = lambda do
            if is_current_user_in_conversation
              render turbo_stream: turbo_stream.replace(
                helpers.dom_id(@conversation),
                partial: 'better_together/conversations/conversation_content',
                locals: { conversation: @conversation, messages: @messages, message: @message }
              )
            else
              render turbo_stream: turbo_stream.action(:full_page_redirect, conversations_path)
            end
          end

          html_response = lambda do
            if is_current_user_in_conversation
              redirect_to @conversation
            else
              redirect_to conversations_path
            end
          end

          respond_to do |format|
            format.turbo_stream { turbo_stream_response.call }
            format.html { html_response.call }
          end
        else
          respond_to do |format|
            format.turbo_stream do
              render turbo_stream: turbo_stream.update(
                'form_errors',
                partial: 'layouts/better_together/errors',
                locals: { object: @conversation }
              )
            end
          end
        end
      end
    end

    def show # rubocop:todo Metrics/MethodLength, Metrics/AbcSize
      authorize @conversation

      @messages = @conversation.messages.with_all_rich_text.includes(sender: [:string_translations]).order(:created_at)
      @message = @conversation.messages.build

      if @messages.any?
        mark_notifications_read_for_event_records(BetterTogether::NewMessageNotifier, @messages.pluck(:id),
                                                  recipient: helpers.current_person)
      end

      respond_to do |format|
        format.html
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            'conversation_content',
            partial: 'better_together/conversations/conversation_content',
            locals: { conversation: @conversation, messages: @messages, message: @message }
          )
        end
      end
    end

    def leave_conversation # rubocop:todo Metrics/MethodLength, Metrics/AbcSize
      authorize @conversation

      flash[:error] if @conversation.participant_ids.size == 1

      participant = @conversation.conversation_participants.find_by(person: helpers.current_person)

      if participant.destroy
        redirect_to conversations_path, notice: t('better_together.conversations.conversation.left',
                                                  conversation: @conversation.title)
      else
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.update(
              'form_errors',
              partial: 'layouts/better_together/errors',
              locals: { object: @conversation }
            )
          end
        end
      end
    end

    private

    def available_participants
      participants = Person.all

      unless helpers.current_person.permitted_to?('manage_platform')
        # only allow messaging platform mangers unless you are a platform_manager
        participants = participants.where(id: platform_manager_ids)
      end

      participants
    end

    def conversation_params
      params.require(:conversation).permit(:title, participant_ids: [])
    end

    def set_conversation
      @conversation = helpers.current_person.conversations.includes(participants: [
                                                                      :string_translations,
                                                                      :contact_detail,
                                                                      { profile_image_attachment: :blob }
                                                                    ]).find(params[:id])
    end

    def set_conversations
      @conversations = helpers.current_person.conversations.includes(messages: [:sender],
                                                                     participants: [
                                                                       :string_translations,
                                                                       :contact_detail,
                                                                       { profile_image_attachment: :blob }
                                                                     ]).order(updated_at: :desc).distinct(:id)
    end

    def platform_manager_ids
      role = BetterTogether::Role.find_by(identifier: 'platform_manager')
      BetterTogether::PersonPlatformMembership.where(role_id: role.id).pluck(:member_id)
    end
  end
end
