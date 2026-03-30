# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/content/blocks/_iframe_block.html.erb' do
  helper BetterTogether::Content::BlocksHelper
  helper BetterTogether::TranslatableFieldsHelper

  let(:platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, host: true) }
  let(:creator) { create(:better_together_person) }

  before do
    configure_host_platform
  end

  it 'renders a visible fallback with guidance when the iframe origin is not allowlisted' do
    platform.update!(settings: platform.settings.except('csp_frame_src'))
    iframe_block = create(:content_iframe_block, creator:)

    render partial: 'better_together/content/blocks/iframe_block', locals: { iframe_block: }

    page = Capybara.string(rendered)

    expect(page).not_to have_css('iframe')
    expect(rendered).to include(I18n.t('better_together.content.blocks.embeds.blocked_title'))
    expect(rendered).to include('https://forms.btsdev.ca')
    expect(rendered).to include(I18n.t('better_together.content.blocks.embeds.open_in_new_tab'))
  end
end
