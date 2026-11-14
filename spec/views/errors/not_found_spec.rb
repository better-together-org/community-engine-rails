# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'errors/404' do # rubocop:disable RSpec/DescribeClass
  let(:platform) { create(:better_together_platform) }

  before do
    allow(BetterTogether::PublicVisibilityGate).to receive(:allow!).and_return(true)
    view.extend(BetterTogether::PlatformContentSlotsHelper)
    allow(view).to receive_messages(host_platform: platform, home_page_path: '/')
  end

  it 'keeps the standard title in the headline when no headlines are set' do
    render

    expect(Nokogiri::HTML(rendered).at_css('#not-found-headline').text).to eq(I18n.t('errors.not_found.title'))
  end

  it 'shows a platform headline and message' do
    platform.update!(content_slot_blocks_attributes: {
                       not_found_headlines: { type: 'BetterTogether::Content::Html', content_en: 'Nothing here but mushrooms' },
                       not_found_message: { type: 'BetterTogether::Content::RichText', content_en: '<div>Try the forays page</div>' }
                     })
    render
    doc = Nokogiri::HTML(rendered)

    expect([doc.at_css('#not-found-headline').text, doc.at_css('#platform-slot-not-found-message').text])
      .to match([eq('Nothing here but mushrooms'), include('Try the forays page')])
  end
end
