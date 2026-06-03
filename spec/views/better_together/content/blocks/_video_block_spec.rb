# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/content/blocks/_video_block.html.erb' do
  helper BetterTogether::Content::BlocksHelper

  let(:platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, host: true) }
  let(:creator) { create(:better_together_person) }

  before do
    configure_host_platform
  end

  it 'renders an iframe when the embed origin is allowed' do
    platform.update!(settings: platform.settings.merge('csp_frame_src' => ['https://www.youtube.com']))
    video_block = create(:content_video_block, creator:)

    render partial: 'better_together/content/blocks/video_block', locals: { video_block: }

    page = Capybara.string(rendered)

    expect(page).to have_css('iframe[src="https://www.youtube.com/embed/dQw4w9WgXcQ"]')
    expect(rendered).not_to include(I18n.t('better_together.content.blocks.embeds.blocked_title'))
  end

  it 'renders a visible fallback when the embed origin is not allowed' do
    platform.update!(settings: platform.settings.except('csp_frame_src'))
    video_block = create(:content_video_block, creator:)

    render partial: 'better_together/content/blocks/video_block', locals: { video_block: }

    page = Capybara.string(rendered)

    expect(page).not_to have_css('iframe')
    expect(rendered).to include(I18n.t('better_together.content.blocks.embeds.blocked_title'))
    expect(rendered).to include('https://www.youtube.com')
  end
end
