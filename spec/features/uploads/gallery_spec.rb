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

  def create_upload(name, creator:, created_at: Time.current, released: true)
    create(:better_together_upload, name:, creator:, created_at:).tap do |upload|
      upload.file.attach(io: StringIO.new('stub'), filename: "#{name}.txt", content_type: 'text/plain')
      release_upload!(upload) if released
    end
  end

  def create_image_upload(name, creator:, created_at: Time.current)
    image_path = File.expand_path('../../../app/assets/images/better_together/unsplash-community-1.jpeg', __dir__)

    create(:better_together_upload, name:, creator:, created_at:).tap do |upload|
      File.open(image_path, 'rb') do |file|
        upload.file.attach(io: file, filename: "#{name.parameterize}.jpeg", content_type: 'image/jpeg')
      end
    end
  end

  def release_upload!(upload, visibility: 'private')
    upload.file_content_security_subject.update!(
      lifecycle_state: visibility == 'public' ? 'approved_public' : 'approved_private',
      aggregate_verdict: 'clean',
      current_visibility_state: visibility,
      current_ai_ingestion_state: 'eligible',
      released_at: Time.current
    )
  end

  def restrict_upload!(upload)
    upload.file_content_security_subject.update!(
      lifecycle_state: 'blocked_rejected',
      aggregate_verdict: 'blocked',
      current_visibility_state: 'private',
      current_ai_ingestion_state: 'pending_review',
      released_at: nil
    )
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

  scenario 'shows review status counts and filters uploads by status' do
    ready_upload = create_upload('Ready Upload', creator:)
    held_upload = create_upload('Held Upload', creator:, released: false)
    restricted_upload = create_upload('Restricted Upload', creator:, released: false)
    restrict_upload!(restricted_upload)

    visit file_index_path(locale: I18n.default_locale)

    expect(page).to have_text('Review status')
    expect(page).to have_button('All (3)')
    expect(page).to have_button('Ready (1)')
    expect(page).to have_button('Under review (1)')
    expect(page).to have_button('Restricted (1)')

    click_button 'Under review (1)'
    expect(page).to have_selector('[data-name="Held Upload"]', visible: true)
    expect(page).to have_selector('[data-name="Ready Upload"].d-none', visible: :all)
    expect(page).to have_selector('[data-name="Restricted Upload"].d-none', visible: :all)

    click_button 'Restricted (1)'
    expect(page).to have_selector('[data-name="Restricted Upload"]', visible: true)
    expect(page).to have_selector('[data-name="Held Upload"].d-none', visible: :all)

    click_button 'Ready (1)'
    expect(page).to have_selector('[data-name="Ready Upload"]', visible: true)
    expect(page).to have_selector('[data-name="Restricted Upload"].d-none', visible: :all)

    expect(ready_upload.file_content_security_downloadable?).to be(true)
    expect(held_upload.file_content_security_downloadable?).to be(false)
    expect(restricted_upload.file_content_security_downloadable?).to be(false)
  end

  scenario 'renders upload and image library previews for reviewed images' do
    upload = create_image_upload('Gallery Image', creator:)
    release_upload!(upload)

    visit file_index_path(locale: I18n.default_locale)

    card_image = find('[data-better_together--uploads-target="item"] img.card-img-top', match: :first)

    expect(card_image[:src]).to be_present
    expect(URI.parse(card_image[:src]).path).to include('/rails/active_storage/')

    visit new_content_block_path(locale: I18n.default_locale, block_type: 'BetterTogether::Content::Image')
    click_button 'Choose from library'

    expect(page).to have_css('.modal.show', wait: 10)

    library_button = find('.modal.show button[data-action*="image-library#select"]', match: :first)
    library_image = library_button.find('img')
    expect(URI.parse(library_image[:src]).path).to include('/rails/active_storage/blobs/proxy/')
    expect(library_button['data-url']).to be_present
    expect(library_button['data-signed-id']).to eq(upload.file.blob.signed_id)
  end

  scenario 'shows an explanatory empty state when the current person has no reviewed images' do
    other_person = create(:better_together_person)

    other_upload = create_image_upload('Someone Else Image', creator: other_person)
    release_upload!(other_upload)

    own_held_upload = create_image_upload('Held Image', creator:)

    visit new_content_block_path(locale: I18n.default_locale, block_type: 'BetterTogether::Content::Image')
    click_button 'Choose from library'

    expect(page).to have_css('.modal.show', wait: 10)
    expect(page).to have_text('No reviewed image uploads are available in your library yet.')
    expect(page).to have_text('Upload an image first, or switch to the person who uploaded it.')
    expect(page).to have_no_css('.modal.show img')
    expect(own_held_upload.file_content_security_downloadable?).to be(false)
  end

  scenario 'shows only the current person reviewed image uploads in the library' do
    own_upload = create_image_upload('Visible Image', creator:)
    release_upload!(own_upload)

    other_person = create(:better_together_person)
    other_upload = create_image_upload('Hidden Image', creator: other_person)
    release_upload!(other_upload)

    held_upload = create_image_upload('Held Image', creator:)

    visit new_content_block_path(locale: I18n.default_locale, block_type: 'BetterTogether::Content::Image')
    click_button 'Choose from library'

    expect(page).to have_css('.modal.show', wait: 10)
    expect(page).to have_text('Only your reviewed image uploads are available here.')
    expect(page).to have_css('.modal.show img', count: 1)
    expect(page).to have_no_text('Hidden Image')
    expect(held_upload.file_content_security_downloadable?).to be(false)

    library_button = find('.modal.show button[data-action*="image-library#select"]', match: :first)
    expect(library_button['data-signed-id']).to eq(own_upload.file.blob.signed_id)
  end
end
