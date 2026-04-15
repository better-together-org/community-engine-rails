# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Publishing agreement modal integration' do
  before do
    configure_host_platform
  end

  let!(:content_publishing_agreement) do
    BetterTogether::Agreement.find_or_initialize_by(identifier: BetterTogether::PublicVisibilityGate::AGREEMENT_IDENTIFIER).tap do |agreement|
      agreement.title = 'Content Publishing Agreement'
      agreement.active_for_consent = true
      agreement.required_for = :first_publish
      agreement.save!
    end
  end

  describe 'POST /c', :as_platform_manager do
    let(:community_name) { "Blocked Community #{SecureRandom.hex(4)}" }
    let(:params) do
      {
        community: {
          name_en: community_name,
          description_en: 'A public community without prior publishing consent',
          privacy: 'public'
        }
      }
    end

    it 'renders a direct agreement modal launch link on publishing failure' do
      post better_together.communities_path(locale: I18n.locale), params: params

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('The content publishing agreement must be accepted before this can be made public.')
      expect(response.body).to include('agreement-modal-link')
      expect(response.body).to include('data-agreement-mode="direct_accept"')
      expect(response.body).to include(CGI.escapeHTML(better_together.accept_agreement_path(content_publishing_agreement, locale: I18n.locale)))
    end
  end
end
