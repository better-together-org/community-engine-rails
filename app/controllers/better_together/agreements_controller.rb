# frozen_string_literal: true

module BetterTogether
  # CRUD for Agreements
  class AgreementsController < FriendlyResourceController
    skip_before_action :check_platform_privacy, only: :show

    # When the agreement is requested inside a Turbo Frame (from the modal),
    # return only the fragment wrapped in the expected <turbo-frame id="agreement_modal_frame">...</turbo-frame>
    # so Turbo can swap it into the frame. For normal requests, fall back to the
    # default rendering (with layout).
    def show # rubocop:todo Metrics/MethodLength
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

    protected

    def resource_class
      ::BetterTogether::Agreement
    end
  end
end
