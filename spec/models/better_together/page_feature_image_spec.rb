# frozen_string_literal: true

require 'rails_helper'

# A page's feature image is its banner and link-preview picture.
RSpec.describe BetterTogether::Page, '#feature_image' do
  let!(:host_platform) { configure_host_platform }
  let(:png) do
    Base64.strict_decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==')
  end
  let(:data) { Base64.strict_encode64(png) }
  let(:page) { create(:better_together_page, platform: host_platform) }

  def attach_hero_background(page)
    hero = create(:better_together_content_hero, :with_background_image)
    page.page_blocks.create!(block: hero, position: 0)
    page.reload
    hero
  end

  it 'attaches a base64 feature image', :aggregate_failures do
    page.update!(feature_image_data: data, feature_image_filename: 'banner.png')

    expect(page.reload.feature_image).to be_attached
    expect(page.feature_image.filename.to_s).to eq('banner.png')
  end

  it 'removes the feature image through remove_feature_image' do
    page.update!(feature_image_data: data, feature_image_filename: 'banner.png')

    page.update!(remove_feature_image: '1')

    expect(page.reload.feature_image).not_to be_attached
  end

  it 'rejects data that is not an allowed image', :aggregate_failures do
    page.feature_image_data = Base64.strict_encode64('not an image')

    expect(page).not_to be_valid
    expect(page.errors[:feature_image_data]).to be_present
  end

  describe '#share_image' do
    it 'is nil when there is no feature image and no hero background' do
      expect(page.share_image).to be_nil
    end

    it 'falls back to the hero background', :aggregate_failures do
      hero = attach_hero_background(page)

      expect(page.share_image.blob).to eq(hero.background_image_file.blob)
    end

    it 'prefers the feature image over the hero background', :aggregate_failures do
      attach_hero_background(page)
      page.update!(feature_image_data: data, feature_image_filename: 'banner.png')

      expect(page.reload.share_image.blob).to eq(page.feature_image.blob)
    end
  end
end
