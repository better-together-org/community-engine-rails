# frozen_string_literal: true

module BetterTogether
  # Community-scoped controller for membership requests.
  #
  # Public actions (new/create) — no authentication required:
  #   GET  /c/:community_id/membership_requests/new
  #   POST /c/:community_id/membership_requests
  #
  # Community-manager actions (index/show/destroy/approve/decline) — require authentication:
  #   GET    /c/:community_id/membership_requests
  #   GET    /c/:community_id/membership_requests/:id
  #   DELETE /c/:community_id/membership_requests/:id
  #   POST   /c/:community_id/membership_requests/:id/approve
  #   POST   /c/:community_id/membership_requests/:id/decline
  #
  # Host apps may override +validate_captcha_if_enabled?+ to add Turnstile or
  # other captcha validation (same pattern as UsersRegistrationsController).
  class MembershipRequestsController < ApplicationController # rubocop:todo Metrics/ClassLength
    skip_before_action :authenticate_user!, only: %i[new create], raise: false
    skip_before_action :check_platform_privacy

    before_action :set_community
    before_action :set_membership_request, only: %i[show destroy approve decline]
    after_action :verify_authorized

    # GET /c/:community_id/membership_requests
    def index
      authorize BetterTogether::Joatu::MembershipRequest
      @membership_requests = apply_status_filter(
        policy_scope(BetterTogether::Joatu::MembershipRequest)
          .where(target: @community)
          .order(created_at: :desc)
      ).page(params[:page]).per(25)
    end

    # GET /c/:community_id/membership_requests/:id
    def show
      authorize @membership_request
    end

    # GET /c/:community_id/membership_requests/new
    def new
      @membership_request = BetterTogether::Joatu::MembershipRequest.new(target: @community)
      authorize @membership_request
    end

    # POST /c/:community_id/membership_requests
    def create # rubocop:todo Metrics/MethodLength, Metrics/AbcSize
      @membership_request = BetterTogether::Joatu::MembershipRequest.new(
        membership_request_params.merge(
          target: @community,
          status: 'open',
          urgency: 'normal'
        )
      )
      @membership_request.creator = helpers.current_person if helpers.current_person.present?
      authorize @membership_request

      unless validate_captcha_if_enabled?
        handle_captcha_validation_failure(@membership_request)
        respond_to do |format|
          format.html { render :new, status: :unprocessable_entity }
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(
              'membership_request_form',
              partial: 'better_together/membership_requests/form',
              locals: { membership_request: @membership_request, community: @community }
            ), status: :unprocessable_entity
          end
        end
        return
      end

      if @membership_request.save
        respond_to do |format|
          format.html { render :success }
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(
              'membership_request_form',
              partial: 'better_together/membership_requests/success'
            )
          end
        end
      else
        respond_to do |format|
          format.html { render :new, status: :unprocessable_entity }
          format.turbo_stream do
            render status: :unprocessable_entity,
                   turbo_stream: turbo_stream.replace(
                     'membership_request_form',
                     partial: 'better_together/membership_requests/form',
                     locals: { membership_request: @membership_request, community: @community }
                   )
          end
        end
      end
    end

    # DELETE /c/:community_id/membership_requests/:id
    def destroy # rubocop:todo Metrics/MethodLength, Metrics/AbcSize
      authorize @membership_request
      if @membership_request.destroy
        respond_to do |format|
          format.html do
            redirect_to community_membership_requests_path(@community),
                        notice: t('flash.generic.removed',
                                  resource: t('better_together.resources.membership_request'))
          end
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.remove(helpers.dom_id(@membership_request)),
              turbo_stream.replace('flash_messages',
                                   partial: 'layouts/better_together/flash_messages',
                                   locals: { flash: })
            ]
          end
        end
      else
        flash.now[:alert] = t('flash.generic.error_remove',
                              resource: t('better_together.resources.membership_request'))
        respond_to do |format|
          format.html { redirect_to community_membership_requests_path(@community) }
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace('flash_messages',
                                                      partial: 'layouts/better_together/flash_messages',
                                                      locals: { flash: })
          end
        end
      end
    end

    # POST /c/:community_id/membership_requests/:id/approve
    def approve # rubocop:todo Metrics/MethodLength, Metrics/AbcSize
      authorize @membership_request
      @membership_request.approve!(approver: helpers.current_person)
      notice_key = @membership_request.unauthenticated? ? 'approved' : 'approved_direct'
      flash.now[:notice] = t("better_together.membership_requests.flash.#{notice_key}",
                             default: 'Membership request approved.')
      respond_to do |format|
        format.html { redirect_to community_membership_requests_path(@community), notice: flash.now[:notice] }
        format.turbo_stream { render_status_update_turbo_stream }
      end
    rescue StandardError => e
      flash.now[:alert] = t('better_together.membership_requests.flash.approve_failed',
                            default: 'Could not approve the membership request.')
      Rails.logger.error "MembershipRequest#approve! failed [#{e.class.name}] request_id=#{@membership_request.id}"
      respond_to do |format|
        format.html { redirect_to community_membership_request_path(@community, @membership_request) }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace('flash_messages',
                                                    partial: 'layouts/better_together/flash_messages',
                                                    locals: { flash: })
        end
      end
    end

    # POST /c/:community_id/membership_requests/:id/decline
    def decline # rubocop:todo Metrics/MethodLength, Metrics/AbcSize
      authorize @membership_request
      @membership_request.decline!
      flash.now[:notice] = t('better_together.membership_requests.flash.declined',
                             default: 'Membership request declined.')
      respond_to do |format|
        format.html { redirect_to community_membership_requests_path(@community), notice: flash.now[:notice] }
        format.turbo_stream { render_status_update_turbo_stream }
      end
    rescue StandardError => e
      flash.now[:alert] = t('better_together.membership_requests.flash.decline_failed',
                            default: 'Could not decline the membership request.')
      Rails.logger.error "MembershipRequest#decline! failed [#{e.class.name}] request_id=#{@membership_request.id}"
      respond_to do |format|
        format.html { redirect_to community_membership_request_path(@community, @membership_request) }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace('flash_messages',
                                                    partial: 'layouts/better_together/flash_messages',
                                                    locals: { flash: })
        end
      end
    end

    private

    def set_community
      @community = ::BetterTogether::Community.friendly.find(params[:community_id])
    rescue ActiveRecord::RecordNotFound
      redirect_to root_path, alert: t('globals.not_found', default: 'Not found.')
    end

    def set_membership_request
      @membership_request = policy_scope(BetterTogether::Joatu::MembershipRequest)
                            .where(target: @community)
                            .find(params[:id])
    end

    def apply_status_filter(collection)
      status = params[:status]
      return collection if status == 'all' || (params.key?(:status) && status.blank?)
      return collection.where(status: status) if status.present?

      collection.where(status: 'open')
    end

    def membership_request_params
      params.require(:joatu_membership_request).permit(
        :requestor_name,
        :requestor_email,
        :referral_source,
        :description
      )
    end

    def render_status_update_turbo_stream # rubocop:todo Metrics/MethodLength
      render turbo_stream: [
        turbo_stream.replace(
          helpers.dom_id(@membership_request, :status),
          partial: 'better_together/membership_requests/status_badge',
          locals: { membership_request: @membership_request }
        ),
        turbo_stream.replace(
          helpers.dom_id(@membership_request, :actions),
          partial: 'better_together/membership_requests/row_actions',
          locals: { membership_request: @membership_request }
        ),
        turbo_stream.replace('flash_messages',
                             partial: 'layouts/better_together/flash_messages',
                             locals: { flash: })
      ]
    end

    # Hook for host applications to implement captcha validation.
    # @return [Boolean] true if captcha is valid or not enabled
    def validate_captcha_if_enabled?
      true
    end

    # Hook for captcha failure handling. Override to customise the error message.
    def handle_captcha_validation_failure(resource)
      resource.errors.add(
        :base,
        I18n.t('better_together.membership_requests.captcha_failed',
               default: 'Captcha verification failed. Please try again.')
      )
    end
  end
end
