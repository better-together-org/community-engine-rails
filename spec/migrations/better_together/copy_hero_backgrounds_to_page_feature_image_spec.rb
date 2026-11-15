# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20261115210000_copy_hero_backgrounds_to_page_feature_image')

RSpec.describe CopyHeroBackgroundsToPageFeatureImage, :no_auth do
  let!(:host_platform) { configure_host_platform }
  let(:page) { create(:better_together_page, platform: host_platform) }
  let!(:hero) do
    create(:better_together_content_hero, :with_background_image).tap { |h| page.page_blocks.create!(block: h, position: 0) }
  end

  def migrate(direction, dry_run: nil)
    ENV['DRY_RUN'] = dry_run
    ActiveRecord::Migration.suppress_messages { described_class.new.public_send(direction) }
  ensure
    ENV.delete('DRY_RUN')
  end

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

  it 'leaves an existing feature image alone' do
    png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
    page.reload.update!(feature_image_data: png, feature_image_filename: 'own.png')

    migrate(:up)

    expect(page.reload.feature_image.filename.to_s).to eq('own.png')
  end

  it 'removes only the copied attachment on rollback', :aggregate_failures do
    migrate(:up)
    migrate(:down)

    expect(page.reload.feature_image).not_to be_attached
    expect(hero.reload.background_image_file).to be_attached
  end
end
