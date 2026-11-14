# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Platform content slots', :as_platform_manager do # rubocop:disable RSpec/DescribeClass, RSpec/MultipleDescribes
  let(:locale) { I18n.default_locale }
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) }
  let(:platform_path) { better_together.platform_path(locale:, id: host_platform.slug) }
  let(:rich_text) { 'BetterTogether::Content::RichText' }

  before { allow(BetterTogether::PublicVisibilityGate).to receive(:allow!).and_return(true) }

  def patch_slots(slots)
    patch platform_path, params: { platform: { content_slot_blocks_attributes: slots } }
  end

  it 'creates a slot block and shows it around the page' do # rubocop:disable RSpec/MultipleExpectations
    patch_slots(header_above: { type: rich_text, content_en: '<div>Next foray soon</div>' },
                footer_above: { type: 'BetterTogether::Content::Html', content_en: '<p>Funded by</p><script>x()</script>' })

    expect(response).to have_http_status(:see_other)
    get better_together.home_page_path(locale:)
    doc = parsed_response
    expect(doc.at_css('#platform-slot-header-above').text).to include('Next foray soon')
    expect(doc.at_css('#platform-slot-footer-above').text).to include('Funded by')
    expect(doc.at_css('#platform-slot-footer-above script')).to be_nil
  end

  it 'places the header slot before the site header and the footer slot before the footer' do
    patch_slots(header_above: { type: rich_text, content_en: '<div>Top</div>' },
                footer_above: { type: rich_text, content_en: '<div>Bottom</div>' })
    get better_together.home_page_path(locale:)
    body = response.body

    expect([body.index('platform-slot-header-above'), body.index('platform-slot-footer-above')]).to eq(
      [body.index('platform-slot-header-above'), body.index('platform-slot-footer-above')].sort
    )
  end

  it 'updates the existing block in place' do
    patch_slots(header_above: { type: rich_text, content_en: '<div>One</div>' })
    original_id = host_platform.reload.content_slot_block(:header_above).id
    patch_slots(header_above: { content_en: '<div>Two</div>' })

    block = BetterTogether::Platform.find(host_platform.id).content_slot_block(:header_above)
    expect([block.id, block.content.to_plain_text]).to eq([original_id, 'Two'])
  end

  it 'removes a slot block' do
    patch_slots(header_above: { type: rich_text, content_en: '<div>One</div>' })
    patch_slots(header_above: { remove: '1' })

    expect(BetterTogether::Platform.find(host_platform.id).content_slot_block(:header_above)).to be_nil
  end

  it 'rejects a content type the slot does not allow and creates nothing' do # rubocop:disable RSpec/MultipleExpectations
    expect do
      patch_slots(header_above: { type: 'BetterTogether::Content::Hero', content_en: 'x' })
    end.not_to(change(BetterTogether::Content::Block, :count))

    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'rejects over-limit content and keeps the old content' do # rubocop:disable RSpec/MultipleExpectations
    patch_slots(header_above: { type: rich_text, content_en: '<div>Old</div>' })
    patch_slots(header_above: { content_en: "<div>#{'a' * 21_000}</div>" })

    expect(response).to have_http_status(:unprocessable_content)
    expect(BetterTogether::Platform.find(host_platform.id).content_slot_block(:header_above).content.to_plain_text)
      .to eq('Old')
  end

  it 'does not accept a markdown file path for a slot' do
    patch_slots(header_above: { type: 'BetterTogether::Content::Markdown', markdown_source_en: 'Hi',
                                markdown_file_path: '/etc/passwd', auto_sync_from_file: '1' })

    expect(BetterTogether::Platform.find(host_platform.id).content_slot_block(:header_above).markdown_file_path).to be_blank
  end

  it 'shows a platform headline on a 404' do
    patch_slots(not_found_headlines: { type: 'BetterTogether::Content::Html', content_en: 'Nothing here but mushrooms' })
    get "/#{locale}/no-such-page-for-slots"

    expect(parsed_response.at_css('#not-found-headline').text).to eq('Nothing here but mushrooms')
  end
end

RSpec.describe 'Platform content slots authorization', :as_user do # rubocop:disable RSpec/DescribeClass, RSpec/MultipleDescribes
  let(:locale) { I18n.default_locale }
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) }

  before { allow(BetterTogether::PublicVisibilityGate).to receive(:allow!).and_return(true) }

  it 'does not let an ordinary member change slot content' do # rubocop:disable RSpec/MultipleExpectations
    expect do
      patch better_together.platform_path(locale:, id: host_platform.slug),
            params: { platform: { content_slot_blocks_attributes: {
              header_above: { type: 'BetterTogether::Content::RichText', content_en: '<div>Sneaky</div>' }
            } } }
    end.not_to(change(BetterTogether::Content::Block, :count))

    expect(response).not_to have_http_status(:see_other)
    expect(BetterTogether::Platform.find(host_platform.id).content_slot_block(:header_above)).to be_nil
  end
end
