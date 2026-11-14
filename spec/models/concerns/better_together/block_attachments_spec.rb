# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::BlockAttachments do
  let(:registry) { BetterTogether::ContentSecurity::AttachableRegistry }
  let(:platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, host: true) }
  let(:person) { create(:better_together_person) }
  let(:png) do
    Base64.strict_decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==')
  end
  let(:image_block) do
    BetterTogether::Content::Image.create!(platform:, privacy: 'public', identifier: 'ba-img', creator: person,
                                           caption: 'Sunrise', media_data: Base64.strict_encode64(png),
                                           media_filename: 'sunrise.png')
  end
  let(:post) { build(:better_together_post, platform:, content: 'Sunrise over the harbour') }

  before do
    BetterTogether::Content::Image.include(ActionText::Attachable)
    registry.register('BetterTogether::Content::Image')
  end

  after { registry.reset! }

  def attached_ids(record)
    BetterTogether::Post.find(record.id).content.body.attachables.map(&:id)
  end

  it 'attaches registered blocks ahead of the text', :aggregate_failures do
    post.attachment_block_ids = [image_block.id]
    post.save!

    expect(attached_ids(post)).to eq([image_block.id])
    expect(post.reload.content.body.to_html).to match(/\A<action-text-attachment.*Sunrise over the harbour/m)
  end

  it 'rejects an unknown id and a class that is not registered', :aggregate_failures do
    post.attachment_block_ids = [SecureRandom.uuid]
    expect(post).not_to be_valid

    registry.reset!
    post.attachment_block_ids = [image_block.id]
    expect(post).not_to be_valid
  end

  it 'keeps the blocks when only new text is sent on update', :aggregate_failures do
    post.attachment_block_ids = [image_block.id]
    post.save!
    fresh = BetterTogether::Post.find(post.id)
    fresh.update!(content: 'In port 8:42 AM')

    expect(attached_ids(fresh)).to eq([image_block.id])
    expect(fresh.reload.content.body.to_html).to include('In port 8:42 AM')
    expect(fresh.content.body.to_html).not_to include('Sunrise over')
  end

  it 'does not repeat the blocks on an unrelated update', :aggregate_failures do
    post.attachment_block_ids = [image_block.id]
    post.save!
    post.update!(title: 'Renamed')

    expect(attached_ids(post)).to eq([image_block.id])
  end
end
