# frozen_string_literal: true

module BetterTogether
  # Allows for CRUD operations for Person Platform Memberships
  class PersonPlatformMembershipsController < ApplicationController
    before_action :set_platform
    before_action :set_person_platform_membership, only: %i[show edit update destroy]
    before_action :authorize_person_platform_membership, only: %i[show edit update destroy]
    before_action :authorize_index, only: %i[index]
    before_action :authorize_new_action, only: %i[new]
    before_action :set_form_data, only: %i[new edit]

    # GET /platforms/:platform_id/person_platform_memberships
    def index
      @person_platform_memberships = @platform.memberships_with_associations
    end

    # GET /platforms/:platform_id/person_platform_memberships/:id
    def show; end

    # GET /platforms/:platform_id/person_platform_memberships/new
    def new
      @person_platform_membership = BetterTogether::PersonPlatformMembership.new(joinable_id: @platform.id)
    end

    # GET /platforms/:platform_id/person_platform_memberships/:id/edit
    def edit; end

    # PATCH/PUT /platforms/:platform_id/person_platform_memberships/:id
    def update # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      authorize @person_platform_membership

      respond_to do |format|
        if @person_platform_membership.update(person_platform_membership_params)

          format.turbo_stream do
            # Check if request is for individual member card (turbo frame)
            if request.headers['Turbo-Frame'].present?
              render turbo_stream: turbo_stream.replace(
                helpers.dom_id(@person_platform_membership, :member_card),
                partial: 'better_together/person_platform_memberships/person_platform_membership_member',
                locals: { person_platform_membership: @person_platform_membership }
              )
            else
              render turbo_stream: turbo_stream.replace(
                'platform_members_list',
                partial: 'better_together/person_platform_memberships/members_list',
                locals: { platform: @platform, memberships: @platform.memberships_with_associations }
              )
            end
          end
          format.html do
            redirect_to [@platform, @person_platform_membership],
                        notice: t('flash.generic.updated', resource: t('resources.person_platform_membership'))
          end
        else
          set_form_data
          format.turbo_stream do
            render turbo_stream: turbo_stream.update(
              'form_errors',
              partial: 'layouts/better_together/errors',
              locals: { object: @person_platform_membership }
            )
          end
          format.html { render :edit, status: :unprocessable_content }
        end
      end
    end

    # POST /platforms/:platform_id/person_platform_memberships
    def create # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      @person_platform_membership = BetterTogether::PersonPlatformMembership.new(
        person_platform_membership_params.merge(joinable_id: @platform.id, status: 'active')
      )
      authorize @person_platform_membership

      respond_to do |format|
        if @person_platform_membership.save
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.append(
                'platform_members_list',
                partial: 'better_together/person_platform_memberships/person_platform_membership_member',
                locals: { person_platform_membership: @person_platform_membership }
              ),
              turbo_stream.update(
                'flash_messages',
                partial: 'layouts/better_together/flash_messages',
                locals: { flash: { notice: t('flash.generic.created', resource: t('resources.person_platform_membership')) } }
              )
            ]
          end
          format.html do
            redirect_to @platform, notice: t('flash.generic.created',
                                             resource: t('resources.person_platform_membership'))
          end
        else
          set_form_data
          format.turbo_stream do
            render turbo_stream: turbo_stream.update(
              'form_errors',
              partial: 'layouts/better_together/errors',
              locals: { object: @person_platform_membership }
            )
          end
          format.html { render :new, status: :unprocessable_content }
        end
      end
    end

    # DELETE /platforms/:platform_id/person_platform_memberships/:id
    def destroy # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      authorize @person_platform_membership

      if @person_platform_membership.destroy

        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.remove(helpers.dom_id(@person_platform_membership)),
              turbo_stream.update(
                'flash_messages',
                partial: 'layouts/better_together/flash_messages',
                locals: { flash: { notice: t('flash.generic.destroyed',
                                             resource: t('resources.person_platform_membership')) } }
              )
            ]
          end
          format.html do
            redirect_to @platform,
                        notice: t('flash.generic.destroyed', resource: t('resources.person_platform_membership')),
                        status: :see_other
          end
        end
      else
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.update(
              'flash_messages',
              partial: 'layouts/better_together/flash_messages',
              locals: { flash: { alert: @person_platform_membership.errors.full_messages.to_sentence } }
            )
          end
          format.html do
            redirect_to @platform,
                        alert: @person_platform_membership.errors.full_messages.to_sentence,
                        status: :unprocessable_content
          end
        end
      end
    end

    private

    # Set the platform for scoped operations
    def set_platform
      @platform = ::BetterTogether::Platform.friendly.find(params[:platform_id])
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_person_platform_membership
      @person_platform_membership = BetterTogether::PersonPlatformMembership.find(params[:id])
      raise ActiveRecord::RecordNotFound unless @person_platform_membership.joinable_id == @platform.id
    end

    # Only allow a list of trusted parameters through.
    def person_platform_membership_params
      params.require(:person_platform_membership).permit(:member_id, :role_id, :joinable_id)
    end

    # Adds a policy check for the person platform membership
    def authorize_person_platform_membership
      authorize @person_platform_membership
    end

    # Authorizes the index action
    def authorize_index
      authorize BetterTogether::PersonPlatformMembership
    end

    # Authorizes the new action
    def authorize_new_action
      authorize BetterTogether::PersonPlatformMembership
    end

    # Sets up data needed for the form
    def set_form_data
      @available_people = @platform.community.person_members.where.not(
        id: @platform.person_platform_memberships.pluck(:member_id)
      )
      @available_roles = ::BetterTogether::Role.where(resource_type: 'BetterTogether::Platform')
    end
  end
end
