# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'uploads accessibility', :accessibility, :js, retry: 0 do
  include BetterTogether::DeviseSessionHelpers

  let(:creator) { BetterTogether::User.find_by(email: 'manager@example.test').person }

  def create_upload(name, creator:, released: true)
    create(:better_together_upload, name:, creator:).tap do |upload|
      upload.file.attach(io: StringIO.new('stub'), filename: "#{name}.txt", content_type: 'text/plain')
      release_upload!(upload) if released
    end
  end

  def create_image_upload(name, creator:)
    image_path = File.expand_path('../../app/assets/images/better_together/unsplash-community-1.jpeg', __dir__)
    create(:better_together_upload, name:, creator:).tap do |upload|
      File.open(image_path, 'rb') do |file|
        upload.file.attach(io: file, filename: "#{name.parameterize}.jpeg", content_type: 'image/jpeg')
      end
    end
  end

  def release_upload!(upload)
    upload.file_content_security_subject.update!(
      lifecycle_state: 'approved_private',
      aggregate_verdict: 'clean',
      current_visibility_state: 'private',
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

  before do
    configure_host_platform
    login_as_platform_manager
  end

  describe 'uploads index page' do
    before do
      create_upload('Ready Upload', creator:)
      create_upload('Held Upload', creator:, released: false)
      restricted = create_upload('Restricted Upload', creator:, released: false)
      restrict_upload!(restricted)

      visit file_index_path(locale: I18n.default_locale)
      find('[data-better_together--uploads-target="item"]', wait: 10)
    end

    it 'passes WCAG 2.1 AA on the uploads gallery page' do
      expect(page).to be_axe_clean
        .within('main')
        .according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)
    end
  end

  describe 'image library modal' do
    before do
      create_image_upload('Library Image', creator:).tap { |u| release_upload!(u) }

      visit new_content_block_path(locale: I18n.default_locale, block_type: 'BetterTogether::Content::Image')
      click_button 'Choose from library'
      find('.modal.show', wait: 10)
    end

    it 'passes WCAG 2.1 AA inside the library modal with images present' do
      expect(page).to be_axe_clean
        .within('.modal.show')
        .according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)
    end
  end

  describe 'image library modal — empty state' do
    before do
      visit new_content_block_path(locale: I18n.default_locale, block_type: 'BetterTogether::Content::Image')
      click_button 'Choose from library'
      find('.modal.show', wait: 10)
    end

    it 'passes WCAG 2.1 AA inside the library modal with no images' do
      expect(page).to be_axe_clean
        .within('.modal.show')
        .according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)
    end
  end
end
