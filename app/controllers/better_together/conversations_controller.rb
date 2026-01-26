# frozen_string_literal: true

module BetterTogether
  # Handles managing conversations
  class ConversationsController < ApplicationController # rubocop:todo Metrics/ClassLength
    include BetterTogether::NotificationReadable

    before_action :authenticate_user!
    before_action :require_person
    before_action :disallow_robots
    before_action :set_conversations, only: %i[index new show]
    before_action :set_conversation, only: %i[show update leave_conversation]
    after_action :verify_authorized

    layout 'better_together/conversation', only: %i[show]

    helper_method :available_participants

    def index
      # Conversations list is prepared by set_conversations (before_action)
      # Provide a blank conversation for the new-conversation form in the sidebar
      @conversation = Conversation.new
      authorize @conversation
    end

    def new
      if params[:conversation].present?
        conv_params = params.require(:conversation).permit(:title, participant_ids: [])
        @conversation = Conversation.new(conv_params)
      else
        @conversation = Conversation.new
      end

      # Ensure nested message is available for the form (so users can create the first message inline)
      @conversation.messages.build if @conversation.messages.empty?

      authorize @conversation
    end

    def create # rubocop:todo Metrics/MethodLength, Metrics/AbcSize
      # Check if user supplied only disallowed participants
      submitted_any = conversation_params[:participant_ids].present?
      filtered_params = conversation_params_filtered
      filtered_empty = Array(filtered_params[:participant_ids]).blank?

      @conversation = Conversation.new(filtered_params.merge(creator: helpers.current_person))

      # If nested messages were provided, ensure the sender is set to the creator/current person
      if @conversation.messages.any?
        @conversation.messages.each do |m|
          m.sender = helpers.current_person
        end
      end

      authorize @conversation

      if submitted_any && filtered_empty
        @conversation.errors.add(:conversation_participants,
                                 t('better_together.conversations.errors.no_permitted_participants'))
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.update(
              'form_errors',
              partial: 'layouts/better_together/errors',
              locals: { object: @conversation }
            ), status: :unprocessable_entity
          end
          format.html do
            # Ensure sidebar has data when rendering the new template
            set_conversations
            render :new, status: :unprocessable_entity
          end
        end
      elsif @conversation.save
        @conversation.add_participant_safe(helpers.current_person)

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
          format.html do
            # Ensure sidebar has data when rendering the new template
            set_conversations
            render :new
          end
        end
      end
    end

    def update # rubocop:todo Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
      authorize @conversation
      ActiveRecord::Base.transaction do # rubocop:todo Metrics/BlockLength
        submitted_any = conversation_params[:participant_ids].present?
        filtered_params = conversation_params_filtered
        filtered_empty = Array(filtered_params[:participant_ids]).blank?

        if submitted_any && filtered_empty
          @conversation.errors.add(:conversation_participants,
                                   t('better_together.conversations.errors.no_permitted_participants'))
          respond_to do |format|
            format.turbo_stream do
              render turbo_stream: turbo_stream.update(
                'form_errors',
                partial: 'layouts/better_together/errors',
                locals: { object: @conversation }
              ), status: :unprocessable_entity
            end
            format.html do
              # Ensure sidebar has data when rendering the show template
              set_conversations
              # Ensure messages variables are set for the show template
              @messages = @conversation.messages.with_all_rich_text
                                       .includes(sender: [:string_translations]).order(:created_at)
              @message = @conversation.messages.build
              render :show, status: :unprocessable_entity
            end
          end
        elsif @conversation.update(filtered_params)
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
              authorize @conversation
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

    def require_person
      return if helpers.current_person

      skip_authorization
      flash[:alert] = t('better_together.conversations.errors.person_required')
      redirect_to BetterTogether::Engine.routes.url_helpers.root_path
    end

    def available_participants
      # Delegate to policy to centralize participant permission logic
      ConversationPolicy.new(helpers.current_user, Conversation.new).permitted_participants
    end

    def conversation_params
      # Use model-defined permitted attributes so nested attributes composition stays DRY
      params.require(:conversation).permit(*Conversation.permitted_attributes)
    end

    # Ensure participant_ids only include people the agent is allowed to message.
    # If none remain, keep it empty; creator is always added after create.
    def conversation_params_filtered # rubocop:todo Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
      permitted = ConversationPolicy.new(helpers.current_user, Conversation.new).permitted_participants
      permitted_ids = permitted.pluck(:id)
      # Always allow the current person (creator/participant) to appear in the list
      permitted_ids << helpers.current_person.id

      cp = conversation_params.dup

      # Filter participant_ids to only those the agent may message
      if cp[:participant_ids].present?
        cp[:participant_ids] = Array(cp[:participant_ids]).map(&:presence).compact & permitted_ids
      end

      # Protect nested messages on update: only allow creating messages via the create path.
      # On update, permit edits only to existing messages that belong to the current person,
      # and only allow their content (prevent sender_id spoofing or reassigning other people's messages).
      if action_name == 'update' && cp[:messages_attributes].present?
        safe_messages = Array(cp[:messages_attributes]).map do |m|
          # handle ActionController::Parameters or Hash
          attrs = m.respond_to?(:to_h) ? m.to_h : m
          msg_id = attrs['id'] || attrs[:id]
          next nil unless msg_id

          msg = BetterTogether::Message.find_by(id: msg_id)
          next nil unless msg && helpers.current_person && msg.sender_id == helpers.current_person.id

          # Only allow content edits through this path
          { 'id' => msg_id, 'content' => attrs['content'] || attrs[:content] }
        end.compact

        # Replace messages_attributes with the vetted set (or nil if none)
        cp[:messages_attributes] = safe_messages.presence
      end

      # On create, leave messages_attributes as-is so nested creation works; controller will set sender.
      cp
    end

    def set_conversation # rubocop:todo Metrics/MethodLength
      scope = helpers.current_person.conversations.includes(participants: [
                                                              :string_translations,
                                                              :contact_detail,
                                                              { profile_image_attachment: :blob }
                                                            ])
      @conversation = scope.find(params[:id])
      @set_conversation ||= Conversation.includes(participants: [
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

    # platform_manager_ids now inferred by policy; kept here only if needed elsewhere
  end
end
