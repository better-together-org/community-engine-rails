# frozen_string_literal: true

module BetterTogether
  # Handles managing conversations
  class ConversationsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_conversations
    before_action :set_conversation, only: %i[show]

    helper_method :available_participants

    def index; end

    def new
      @conversation = Conversation.new
    end

    def create # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      @conversation = Conversation.new(conversation_params.merge(creator: helpers.current_person))
      if @conversation.save
        @conversation.participants << helpers.current_person

        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to @conversation }
        end
      else
        render :new
      end
    end

    def show # rubocop:todo Metrics/MethodLength
      @messages = @conversation.messages.order(:created_at)
      @message = @conversation.messages.build

      respond_to do |format|
        format.html
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            'conversation_content',
            partial: 'better_together/conversations/conversation_content',
            locals: { conversation: @conversation, messages: @messages }
          )
        end
      end
    end

    private

    def available_participants
      participants = Person
            .where.not(id: helpers.current_person.id)

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
      @conversation = Conversation.find(params[:id])
    end

    def set_conversations
      @conversations = helpers.current_person.conversations.order(updated_at: :desc)
    end

    def platform_manager_ids
      role = BetterTogether::Role.find_by(identifier: 'platform_manager')
      BetterTogether::PersonPlatformMembership.where(role_id: role.id).pluck(:member_id)
    end
  end
end
