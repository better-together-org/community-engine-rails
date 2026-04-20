# frozen_string_literal: true

module BetterTogether
  # CRUD for Agreements
  class AgreementsController < FriendlyResourceController
    skip_before_action :check_platform_privacy, only: :show
    before_action :authenticate_user!, only: :accept
    before_action :set_resource_instance, only: :accept
    before_action :authorize_resource, only: :accept

    # When the agreement is requested inside a Turbo Frame (from the modal),
    # return only the fragment wrapped in the expected <turbo-frame id="agreement_modal_frame">...</turbo-frame>
    # so Turbo can swap it into the frame. For normal requests, fall back to the
    # default rendering (with layout).
    def show # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      set_resource_instance unless @resource&.persisted?
      @agreement = @resource || resource_instance
      authorize @agreement

      if @agreement.page
        @page = @agreement.page
        @content_blocks = @page.content_blocks
        @layout = 'layouts/better_together/page'
        @layout = @page.layout if @page.layout.present?
      end

      # Check if this is a Turbo Frame request
      if request.headers['Turbo-Frame'].present?
        Rails.logger.debug 'Rendering turbo frame response'
        render partial: 'modal_content', layout: false
      else
        Rails.logger.debug 'Rendering normal response'
        # Normal full-page rendering continues with the view
      end
    end

    def new
      @agreement = resource_instance
      authorize @agreement unless pundit_policy_authorized?
    end

    def edit
      set_resource_instance unless @resource&.persisted?
      @agreement = @resource || resource_instance
      authorize @agreement unless pundit_policy_authorized?
    end

    # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
    def accept
      unless current_user.person.present?
        render json: { error: 'No participant is available for agreement acceptance.' }, status: :unprocessable_entity
        return
      end

      unless direct_accept_eligible?(resource_instance)
        render json: { error: 'This agreement cannot be accepted from this flow.' }, status: :unprocessable_entity
        return
      end

      acceptance = BetterTogether::AgreementAcceptanceRecorder.record!(
        agreement: resource_instance,
        participant: current_user.person,
        acceptance_method: :agreement_review,
        accepted_at: Time.current,
        context: { request:, flow: 'publish_modal' }
      )

      render json: {
        status: 'accepted',
        agreement_identifier: resource_instance.identifier,
        accepted_at: acceptance.accepted_at&.utc&.iso8601(6),
        message: 'Agreement accepted.'
      }
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    protected

    def resource_class
      ::BetterTogether::Agreement
    end

    private

    def resource_instance(attrs = {})
      super.tap { |agreement| @agreement = agreement }
    end

    def set_resource_instance
      super.tap { |agreement| @agreement = agreement }
    end

    def direct_accept_eligible?(agreement)
      agreement.active_for_consent? && agreement.required_for_first_publish?
    end
  end
end
