# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Event, '#attachment_block_ids' do
  include RequestSpecHelper

  let(:png) do
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
  end
  let(:event) { create(:better_together_event, description: '<p>About the night.</p>') }
  let(:block) do
    BetterTogether::Content::Image.create!(platform: event.platform, privacy: 'public', identifier: 'rac-1-image',
                                           creator: create(:better_together_person), media_data: png,
                                           media_filename: 'cover.png', caption: 'Poster', alt_text: 'The poster')
  end

  before do
    configure_host_platform
    BetterTogether::Content::Image.include(ActionText::Attachable)
    BetterTogether::ContentSecurity::AttachableRegistry.register('BetterTogether::Content::Image')
  end

  after { BetterTogether::ContentSecurity::AttachableRegistry.reset! }

  def attached_ids
    event.reload.description.body.attachables.grep(BetterTogether::Content::Block).map(&:id)
  end

  it 'appends the block after the description text', :aggregate_failures do
    event.update!(attachment_block_ids: [block.id])
    html = event.reload.description.body.to_html

    expect(html).to start_with('<div class="trix-content">').or start_with('<p>About')
    expect(html.index('About the night')).to be < html.index('action-text-attachment')
    expect(attached_ids).to eq([block.id])
  end

  it 'adds the block once however often it is sent' do
    2.times { event.update!(attachment_block_ids: [block.id], name: "Night #{rand(1000)}") }

    expect(attached_ids).to eq([block.id])
  end

  it 'refuses a block that does not exist' do
    event.attachment_block_ids = [SecureRandom.uuid]

    expect(event).not_to be_valid
  end
end
