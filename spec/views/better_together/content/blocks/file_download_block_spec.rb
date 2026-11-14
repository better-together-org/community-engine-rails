# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/content/blocks/_file_download_block' do
  let(:upload) do
    create(:better_together_upload, privacy: 'public').tap do |record|
      record.file.attach(io: StringIO.new('x' * 2048), filename: 'minutes.pdf', content_type: 'application/pdf')
    end
  end
  let(:block) do
    create(:content_file_download_block, upload_id: upload.id, label_en: 'Board <b>minutes</b>')
  end

  before do
    configure_host_platform
    view.define_singleton_method(:content_actions_visible_for?) { |_block| false }
    without_partial_double_verification do
      allow(view).to receive(:policy).and_return(instance_double(BetterTogether::UploadPolicy, download?: true))
    end
  end

  def render_block(record)
    render partial: 'better_together/content/blocks/file_download_block',
           locals: { file_download_block: record }
  end

  it 'links to the download with type and size', :aggregate_failures do
    render_block(block)

    expect(rendered).to have_css(%(.file-download-block__title a[href$="/f/#{upload.id}/download"]))
    expect(rendered).to have_css('.file-download-block__meta', text: 'PDF, 2 KB')
  end

  it 'links to the inline view when configured' do
    block.update!(open_inline: 'true')
    render_block(block)

    expect(rendered).to have_css(%(.file-download-block__title a[href$="/f/#{upload.id}"][target="_blank"]))
  end

  it 'escapes the label' do
    render_block(block)

    expect(rendered).not_to include('<b>minutes</b>')
  end

  it 'shows an empty state when the upload is gone' do
    block.update!(upload_id: SecureRandom.uuid)
    render_block(block)

    expect(rendered).to have_css('.file-download-block__empty', text: 'This file is not available.')
  end
end
