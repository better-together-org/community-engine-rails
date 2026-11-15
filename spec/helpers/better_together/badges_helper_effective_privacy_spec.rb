# frozen_string_literal: true

require 'rails_helper'

module BetterTogether # :nodoc:
  RSpec.describe BadgesHelper, '#privacy_badge effective visibility' do
    let(:private_platform) { create(:better_together_platform, privacy: 'private', host: false) }
    let(:public_platform) { create(:better_together_platform, privacy: 'public', host: false) }

    it 'adds a "visible as" badge when the platform holds a public record back' do
      page = create(:better_together_page, platform: private_platform, privacy: 'public')

      html = helper.privacy_badge(page)

      expect(html).to include(helper.dom_id(page, :effective_privacy_badge))
      expect(html).to include('data-effective-privacy="community"')
      expect(html).to include('Visible as')
    end

    it 'renders only the privacy badge when nothing is capped' do
      page = create(:better_together_page, platform: public_platform,
                                           community: public_platform.community, privacy: 'public')
      page.community.update_columns(privacy: 'public') # rubocop:disable Rails/SkipsModelValidations

      expect(helper.privacy_badge(page.reload)).not_to include('effective_privacy_badge')
    end
  end
end
