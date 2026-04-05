# frozen_string_literal: true

require 'rails_helper'
require 'uri'

RSpec.describe 'uploads gallery', :js do # rubocop:disable Metrics/BlockLength
  include BetterTogether::DeviseSessionHelpers

  let(:creator) { BetterTogether::User.find_by(email: 'manager@example.test').person }

  before do
    configure_host_platform
    login_as_platform_manager
  end

  def create_upload(name, creator:, created_at: Time.current)
    create(:better_together_upload, name:, creator:, created_at:).tap do |upload|
      upload.file.attach(io: StringIO.new('stub'), filename: "#{name}.txt", content_type: 'text/plain')
    end
  end

  scenario 'searches, sorts, and copies upload urls' do
    create_upload('Alpha', creator:, created_at: 2.days.ago)
    create_upload('Beta', creator:, created_at: 1.day.ago)

    visit file_index_path(locale: I18n.default_locale)

    expect(page.all('[data-better_together--uploads-target="item"] .card-title').map(&:text))
      .to eq(%w[Beta Alpha])

    fill_in placeholder: 'Search uploads', with: 'Al'
    expect(page).to have_selector('[data-name="Alpha"]', visible: true)
    expect(page).to have_selector('[data-name="Beta"].d-none', visible: :all)

    find('select[data-better_together--uploads-target="sort"]').find('option', text: 'Name').select_option
    expect(page).to have_selector('[data-name="Alpha"]', visible: true)
    expect(page).to have_selector('[data-name="Beta"].d-none', visible: :all)

    fill_in placeholder: 'Search uploads', with: ''
    expect(page.all('[data-better_together--uploads-target="item"] .card-title').map(&:text))
      .to eq(%w[Alpha Beta])

    copy_button = find('button', text: 'Copy URL', match: :first)
    page.execute_script <<~JS
      window.copiedText = null;
      Object.defineProperty(navigator, "clipboard", {
        value: { writeText: function(t){ window.copiedText = t } }
      });
    JS
    copy_button.click
    expect(page.evaluate_script('window.copiedText')).to eq(copy_button['data-url'])
  end

  scenario 'uses the current request host for upload and image library previews' do
    image_path = File.expand_path('../../../app/assets/images/better_together/unsplash-community-1.jpeg', __dir__)

    create(:better_together_upload, name: 'Gallery Image', creator:).tap do |upload|
      File.open(image_path, 'rb') do |file|
        upload.file.attach(io: file, filename: 'gallery-image.jpeg', content_type: 'image/jpeg')
      end
    end

    visit file_index_path(locale: I18n.default_locale)

    current_origin = URI.parse(page.current_url).then { |url| "#{url.scheme}://#{url.host}:#{url.port}" }
    card_image = find('[data-better_together--uploads-target="item"] img.card-img-top', match: :first)
    copy_button = find('button', text: 'Copy URL', match: :first)

    expect(card_image[:src]).to start_with(current_origin)
    expect(copy_button['data-url']).to start_with(current_origin)

    visit new_content_block_path(locale: I18n.default_locale, block_type: 'BetterTogether::Content::Image')
    click_button 'Choose from library'

    expect(page).to have_css('.modal.show', wait: 10)

    library_image = find('.modal.show img', match: :first)
    expect(library_image[:src]).to start_with(current_origin)
    expect(library_image['data-url']).to start_with(current_origin)
  end
end
