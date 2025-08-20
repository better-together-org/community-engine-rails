# frozen_string_literal: true

module BetterTogether
  # CRUD for Agreements
  class AgreementsController < FriendlyResourceController
    skip_before_action :check_platform_privacy, only: :show

    # When the agreement is requested inside a Turbo Frame (from the modal),
    # return only the fragment wrapped in the expected <turbo-frame id="agreement_modal_frame">...</turbo-frame>
    # so Turbo can swap it into the frame. For normal requests, fall back to the
    # default rendering (with layout).
    def show
      if @agreement.page
        @page = @agreement.page
        @content_blocks = @page.content_blocks
        @layout = 'layouts/better_together/page'
        @layout = @page.layout if @page.layout.present?
      end

      return unless turbo_frame_request?

      content = render_to_string(action: :show, layout: false)
      render html: "<turbo-frame id=\"agreement_modal_frame\">#{content}</turbo-frame>".html_safe
    end

    protected

    def resource_class
      ::BetterTogether::Agreement
    end
  end
end
