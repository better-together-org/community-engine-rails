# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20261115210000_copy_hero_backgrounds_to_page_feature_image')

RSpec.describe CopyHeroBackgroundsToPageFeatureImage, :no_auth do
  include ActiveJob::TestHelper

  let!(:host_platform) { configure_host_platform }
  let(:png) { 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==' }
  let(:page) { create(:better_together_page, platform: host_platform) }
  let(:hero) { create(:better_together_content_hero, :with_background_image) }
  let(:attach_hero) do
    lambda do |target, block, position|
      target.page_blocks.create!(block:, position:)
      target.reload
    end
  end

  def migrate(direction, dry_run: nil)
    ENV['DRY_RUN'] = dry_run
    ActiveRecord::Migration.suppress_messages { described_class.new.public_send(direction) }
  ensure
    ENV.delete('DRY_RUN')
  end

  context 'with a hero that has a background image' do
    before { attach_hero.call(page, hero, 0) }

    it 'points the page feature image at the hero blob without copying the file', :aggregate_failures do
      expect { migrate(:up) }.not_to change(ActiveStorage::Blob, :count)

      expect(page.reload.feature_image).to be_attached
      expect(page.feature_image.blob).to eq(hero.background_image_file.blob)
      expect(hero.reload.background_image_file).to be_attached
    end

    it 'changes nothing on a dry run' do
      migrate(:up, dry_run: '1')

      expect(page.reload.feature_image).not_to be_attached
    end

    it 'is safe to run twice' do
      migrate(:up)

      expect { migrate(:up) }.not_to change(ActiveStorage::Attachment, :count)
    end

    it 'removes only the copied attachment on rollback', :aggregate_failures do
      migrate(:up)
      migrate(:down)

      expect(page.reload.feature_image).not_to be_attached
      expect(hero.reload.background_image_file).to be_attached
    end

    it 'leaves a different feature image alone on rollback', :aggregate_failures do
      page.update!(feature_image_data: png, feature_image_filename: 'own.png')

      migrate(:up)
      migrate(:down)

      expect(page.reload.feature_image.filename.to_s).to eq('own.png')
    end
  end

  it 'skips a page that already has a feature image', :aggregate_failures do
    attach_hero.call(page, hero, 0)
    page.update!(feature_image_data: png, feature_image_filename: 'own.png')

    migrate(:up)

    expect(page.reload.feature_image.filename.to_s).to eq('own.png')
    expect(page.feature_image.blob).not_to eq(hero.background_image_file.blob)
  end

  it 'leaves a page without a hero alone' do
    page.page_blocks.create!(block: create(:content_markdown, markdown_source: '## Body'), position: 0)

    expect { migrate(:up) }.not_to change(ActiveStorage::Attachment.where(name: 'feature_image'), :count)
  end

  it 'leaves a page whose hero has no uploaded background alone' do
    attach_hero.call(page, create(:better_together_content_hero), 0)

    migrate(:up)

    expect(page.reload.feature_image).not_to be_attached
  end

  it 'uses the lowest-position hero that has a background image', :aggregate_failures do
    plain = create(:better_together_content_hero)
    second = create(:better_together_content_hero, :with_background_image)
    attach_hero.call(page, second, 3)
    attach_hero.call(page, hero, 1)
    attach_hero.call(page, plain, 0)

    migrate(:up)

    expect(page.reload.feature_image.blob).to eq(hero.background_image_file.blob)
    expect(second.reload.background_image_file).to be_attached
  end

  describe 'the shared blob' do
    before do
      attach_hero.call(page, hero, 0)
      migrate(:up)
    end

    it 'survives purging the hero background', :aggregate_failures do
      hero.reload.background_image_file.purge

      expect(page.reload.feature_image).to be_attached
      expect(page.feature_image.blob.service.exist?(page.feature_image.blob.key)).to be(true)
    end

    it 'survives purging the feature image', :aggregate_failures do
      page.reload.feature_image.purge

      expect(hero.reload.background_image_file).to be_attached
      expect(hero.background_image_file.blob.service.exist?(hero.background_image_file.blob.key)).to be(true)
    end

    it 'survives removing the hero background through the remove accessor', :aggregate_failures do
      perform_enqueued_jobs { hero.reload.update!(remove_background_image_file: '1') }

      expect(hero.reload.background_image_file).not_to be_attached
      expect(page.reload.feature_image).to be_attached
      expect(page.feature_image.blob.service.exist?(page.feature_image.blob.key)).to be(true)
    end

    it 'survives removing the feature image through the remove accessor', :aggregate_failures do
      perform_enqueued_jobs { page.reload.update!(remove_feature_image: '1') }

      expect(page.reload.feature_image).not_to be_attached
      expect(hero.reload.background_image_file).to be_attached
      expect(hero.background_image_file.blob.service.exist?(hero.background_image_file.blob.key)).to be(true)
    end
  end
end
