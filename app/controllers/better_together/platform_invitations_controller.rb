# frozen_string_literal: true

module BetterTogether
  # rubocop:todo Metrics/ClassLength
  class PlatformInvitationsController < ApplicationController # rubocop:todo Style/Documentation
    before_action :set_platform
    before_action :set_platform_invitation, only: %i[destroy resend]
    after_action :verify_authorized

    before_action only: %i[index], if: -> { Rails.env.development? } do
      # Make sure that all Platform Invitation subclasses are loaded in dev to generate new block buttons
      ::BetterTogether::PlatformInvitation.load_all_subclasses
    end

    # GET /platforms/:platform_id/platform_invitations
    def index # rubocop:todo Metrics/MethodLength
      authorize BetterTogether::PlatformInvitation

      # Build filtered and sorted collection with pagination
      @platform_invitations = build_filtered_collection
      @platform_invitations = apply_sorting(@platform_invitations)
      @platform_invitations = @platform_invitations.page(params[:page]).per(25)

      # Preload roles for the form to prevent N+1 queries during rendering
      @community_roles = BetterTogether::Role.where(resource_type: 'BetterTogether::Community')
                                             .includes(:string_translations)
                                             .order(:position)
      @platform_roles = BetterTogether::Role.where(resource_type: 'BetterTogether::Platform')
                                            .includes(:string_translations)
                                            .order(:position)

      # Find the default community member role for the hidden field
      @default_community_role = @community_roles.find_by(identifier: 'community_member')
    end

    # POST /platforms/:platform_id/platform_invitations
    def create # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      @platform_invitation = @platform.invitations.new(platform_invitation_params) do |pi|
        pi.invitable = @platform
        pi.inviter = helpers.current_person
        pi.valid_from = Time.zone.now
        pi.status = 'pending'
        pi.locale = I18n.locale unless pi.locale
      end

      authorize @platform_invitation

      respond_to do |format| # rubocop:todo Metrics/BlockLength
        if @platform_invitation.save
          flash[:notice] = t('flash.generic.created', resource: t('resources.invitation'))
          format.html { redirect_to @platform, notice: flash[:notice] }
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.prepend('platform_invitations_table_body',
                                   partial: 'better_together/platform_invitations/platform_invitation',
                                   locals: { platform_invitation: @platform_invitation }),
              turbo_stream.replace('flash_messages',
                                   partial: 'layouts/better_together/flash_messages',
                                   locals: { flash: })
            ]
          end
        else
          flash.now[:alert] = t('flash.generic.error_create', resource: t('resources.invitation'))
          format.html do
            index
            render :index, status: :unprocessable_entity
          end
          format.turbo_stream do
            streams = [
              turbo_stream.update('invitation_form_errors',
                                  partial: 'layouts/better_together/errors',
                                  locals: { object: @platform_invitation })
            ]
            # Only include flash message stream if not requested to skip
            unless request.headers['X-Skip-Flash-Stream'] == 'true'
              streams << turbo_stream.replace('flash_messages',
                                              partial: 'layouts/better_together/flash_messages',
                                              locals: { flash: })
            end
            render turbo_stream: streams
          end
        end
      end
    end

    def destroy # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      authorize @platform_invitation

      if @platform_invitation.destroy
        flash.now[:notice] = t('flash.generic.removed', resource: t('resources.invitation'))
        respond_to do |format|
          format.html { redirect_to platform_platform_invitations_path(@platform) }
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.remove(helpers.dom_id(@platform_invitation)),
              turbo_stream.replace('flash_messages',
                                   partial: 'layouts/better_together/flash_messages',
                                   locals: { flash: })
            ]
          end
        end
      else
        flash.now[:error] = t('flash.generic.error_remove', resource: t('resources.invitation'))
        respond_to do |format|
          format.html { redirect_to platform_platform_invitations_path(@platform), alert: flash.now[:error] }
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace('flash_messages',
                                                      partial: 'layouts/better_together/flash_messages',
                                                      locals: { flash: })
          end
        end
      end
    end

    # PUT /platforms/:platform_id/platform_invitations/:id/resend
    def resend # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      authorize @platform_invitation

      BetterTogether::PlatformInvitationMailerJob.perform_later(@platform_invitation.id)
      flash[:notice] = t('flash.generic.queued', resource: t('resources.invitation_email'))

      respond_to do |format|
        format.html { redirect_to platform_platform_invitations_path(@platform), notice: flash[:notice] }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(helpers.dom_id(@platform_invitation),
                                 partial: 'better_together/platform_invitations/platform_invitation',
                                 locals: { platform_invitation: @platform_invitation }),
            turbo_stream.replace('flash_messages',
                                 partial: 'layouts/better_together/flash_messages',
                                 locals: { flash: })
          ]
        end
      end
    end

    private

    def set_platform
      @platform = Mobility::Backends::ActiveRecord::KeyValue::StringTranslation.where(
        translatable_type: 'BetterTogether::Platform',
        key: 'slug',
        value: params[:platform_id],
        locale: I18n.available_locales
      ).includes(:translatable).last&.translatable
    end

    def set_platform_invitation
      @platform_invitation = @platform.invitations.find(params[:id])
    end

    def build_filtered_collection # rubocop:todo Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/PerceivedComplexity
      collection = base_collection
      collection = apply_status_filter(collection) if filter_params[:status].present? || params[:status].present?
      collection = apply_email_filter(collection) if filter_params[:search].present? || params[:search].present?
      collection = apply_valid_from_filter(collection) if filter_params[:valid_from].present?
      collection = apply_valid_until_filter(collection) if filter_params[:valid_until].present?
      collection = apply_accepted_at_filter(collection) if filter_params[:accepted_at].present?
      collection = apply_last_sent_filter(collection) if filter_params[:last_sent].present?
      collection
    end

    def apply_sorting(collection) # rubocop:todo Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/MethodLength
      sort_by = params[:sort_by]
      sort_direction = params[:sort_direction] == 'asc' ? :asc : :desc

      default_sort = { created_at: sort_direction }

      case sort_by
      when 'invitee_email'
        collection.order({ invitee_email: sort_direction }.merge(default_sort))
      when 'status'
        collection.order({ status: sort_direction }.merge(default_sort))
      when 'created_at'
        collection.order({ created_at: sort_direction }.merge(default_sort))
      when 'valid_from'
        collection.order({ valid_from: sort_direction }.merge(default_sort))
      when 'valid_until'
        collection.order({ valid_until: sort_direction }.merge(default_sort))
      when 'accepted_at'
        collection.order({ accepted_at: sort_direction }.merge(default_sort))
      when 'last_sent'
        collection.order({ last_sent: sort_direction }.merge(default_sort))
      else
        # Default sort by created_at (newest first)
        collection.order(created_at: :desc)
      end
    end

    def base_collection
      policy_scope(@platform.invitations).includes(
        { inviter: [:string_translations] },
        { invitee: [:string_translations] }
      )
    end

    def apply_status_filter(collection)
      status = filter_params[:status] || params[:status]
      collection.where(status: status) if status.present?
    end

    def apply_email_filter(collection)
      search_term = filter_params[:search] || params[:search]
      return collection unless search_term.present?

      collection.where('invitee_email ILIKE ?', "%#{search_term.strip}%")
    end

    def apply_valid_from_filter(collection)
      date_filter = filter_params[:valid_from]
      return collection unless date_filter.present?

      apply_datetime_filter(collection, :valid_from, date_filter)
    end

    def apply_valid_until_filter(collection)
      date_filter = filter_params[:valid_until]
      return collection unless date_filter.present?

      apply_datetime_filter(collection, :valid_until, date_filter)
    end

    def apply_accepted_at_filter(collection)
      date_filter = filter_params[:accepted_at]
      return collection unless date_filter.present?

      apply_datetime_filter(collection, :accepted_at, date_filter)
    end

    def apply_last_sent_filter(collection)
      date_filter = filter_params[:last_sent]
      return collection unless date_filter.present?

      apply_datetime_filter(collection, :last_sent, date_filter)
    end

    def apply_datetime_filter(collection, column, date_filter)
      return collection unless date_filter.is_a?(Hash)

      table = collection.arel_table
      collection = apply_from_date_filter(collection, table, column, date_filter[:from])
      apply_to_date_filter(collection, table, column, date_filter[:to])
    end

    def apply_from_date_filter(collection, table, column, from_value)
      return collection unless from_value.present?

      from_date = parse_date(from_value)
      from_date ? collection.where(table[column].gteq(from_date.beginning_of_day)) : collection
    end

    def apply_to_date_filter(collection, table, column, to_value)
      return collection unless to_value.present?

      to_date = parse_date(to_value)
      to_date ? collection.where(table[column].lteq(to_date.end_of_day)) : collection
    end

    def parse_date(date_string)
      return nil unless date_string.present?

      Date.parse(date_string.to_s)
    rescue ArgumentError
      nil
    end

    def filter_params
      params[:filters] || {}
    end

    def platform_invitation_params
      params.require(:platform_invitation).permit(
        :invitee_email, :platform_role_id, :community_role_id, :locale,
        :valid_from, :valid_until, :greeting, :type, :session_duration_mins,
        *param_invitation_class.permitted_attributes
      )
    end

    def param_invitation_class
      param_type = params[:platform_invitation]&.[](:type)

      Rails.application.eager_load! unless Rails.env.production? # Ensure all models are loaded
      valid_types = [BetterTogether::PlatformInvitation, *BetterTogether::PlatformInvitation.descendants]
      found_class = valid_types.find { |klass| klass.to_s == param_type }

      found_class || BetterTogether::PlatformInvitation
    end
  end
  # rubocop:enable Metrics/ClassLength
end
