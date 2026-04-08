# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for content security review states',
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let!(:host_platform) { configure_host_platform }
  let!(:user) { find_or_create_test_user('user@example.test', 'SecureTest123!@#', :user) }
  let!(:platform_manager) { find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager) }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    BetterTogether::AccessControlBuilder.seed_data
  end

  after do
    Current.platform = nil
  end

  it 'captures an upload that is under review with helper text' do
    upload = create_upload_for(user, name: 'Held upload evidence', body: 'held upload', filename: 'held-review.txt')

    result = capture_docs_screenshot(
      'content_security_upload_under_review',
      flow: 'upload_under_review',
      role: 'user',
      callouts: [
        {
          selector: '.card .badge.text-bg-warning',
          title: 'Upload remains held before release',
          bullets: [
            'The visible badge marks the file as under review.',
            'Insert and copy actions stay disabled until the attachment is released.',
            'The helper text explains why the file is not yet available in rich text.'
          ]
        }
      ]
    ) do
      capybara_login_as_user
      visit better_together.file_index_path(locale: I18n.default_locale)

      expect(page).to have_text(upload.name)
      expect(page).to have_text('Under review')
      expect(page).to have_text('reviewed before it can be inserted into rich text or shared')
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/content_security_upload_under_review.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/content_security_upload_under_review.png')
  end

  it 'captures a restricted upload with reviewer-facing help text' do
    upload = create_upload_for(user, name: 'Restricted upload evidence', body: 'restricted upload',
                                     filename: 'restricted-review.txt')
    set_restricted!(upload.file_content_security_subject)

    result = capture_docs_screenshot(
      'content_security_upload_restricted',
      flow: 'upload_restricted',
      role: 'user',
      callouts: [
        {
          selector: '.card .badge.text-bg-danger',
          title: 'Restricted uploads stay unavailable',
          bullets: [
            'A blocked or quarantined verdict is surfaced distinctly from general review.',
            'The helper text tells the uploader the file is restricted pending reviewer action.',
            'Disabled actions keep the restricted file from being copied or inserted.'
          ]
        }
      ]
    ) do
      capybara_login_as_user
      visit better_together.file_index_path(locale: I18n.default_locale)

      expect(page).to have_text(upload.name)
      expect(page).to have_text('Restricted')
      expect(page).to have_text('currently restricted while a reviewer checks it')
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/content_security_upload_restricted.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/content_security_upload_restricted.png')
  end

  it 'captures the reviewer queue content-security section' do
    held_upload = create_upload_for(
      platform_manager,
      name: 'Queue review evidence',
      body: 'queue review',
      filename: 'queue-held.txt'
    )
    grant_platform_permission(platform_manager, 'manage_platform_safety')

    result = capture_docs_screenshot(
      'content_security_review_queue',
      flow: 'review_queue',
      role: 'platform_manager',
      callouts: [
        {
          selector: '.card .list-group',
          title: 'Held content items surface in the review queue',
          bullets: [
            'The queue lists attachments still waiting for safety or security review.',
            'The panel explains that uploads and embedded attachments appear here before release.',
            'Reviewers can see the held filename and source surface in the same dashboard.'
          ]
        }
      ]
    ) do
      capybara_login_as_platform_manager
      visit better_together.safety_cases_path(locale: I18n.default_locale)

      expect(page).to have_text('Content security review items')
      expect(page).to have_text('held for safety or security review appear here before release')
      expect(page).to have_text(held_upload.filename)
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/content_security_review_queue.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/content_security_review_queue.png')
  end

  it 'captures an embedded attachment placeholder while under review' do
    conversation, _message, _blob = create_message_with_attachment(user, filename: 'placeholder-held.png')

    result = capture_docs_screenshot(
      'content_security_placeholder_under_review',
      flow: 'placeholder_under_review',
      role: 'user',
      callouts: [
        {
          selector: 'figure.attachment--held-review',
          title: 'Embedded attachment placeholder under review',
          bullets: [
            'The rendered message keeps context while withholding the attachment preview.',
            'The placeholder is announced as a status region for assistive technology.',
            'No image is rendered until the attachment is approved for release.'
          ]
        }
      ]
    ) do
      capybara_login_as_user
      visit better_together.conversation_path(conversation, person_id: user.person, locale: I18n.default_locale)

      expect(page).to have_text('hello')
      expect(page).to have_css('figure.attachment--held-review')
      expect(page).to have_text('Attachment under review')
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/content_security_placeholder_under_review.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/content_security_placeholder_under_review.png')
  end

  it 'captures an embedded attachment placeholder when the attachment is restricted' do
    conversation, message, blob = create_message_with_attachment(user, filename: 'placeholder-restricted.png')
    subject = BetterTogether::ContentSecurity::Subject.find_by!(
      subject: message,
      attachment_name: "content:embed:#{blob.id}"
    )
    set_restricted!(subject)

    result = capture_docs_screenshot(
      'content_security_placeholder_restricted',
      flow: 'placeholder_restricted',
      role: 'user',
      callouts: [
        {
          selector: 'figure.attachment--content-restricted',
          title: 'Restricted embedded attachment placeholder',
          bullets: [
            'Restricted attachments now render a distinct placeholder state.',
            'The copy makes it clear the file is unavailable while reviewer action is pending.',
            'The message body remains readable without exposing the attachment.'
          ]
        }
      ]
    ) do
      capybara_login_as_user
      visit better_together.conversation_path(conversation, person_id: user.person, locale: I18n.default_locale)

      expect(page).to have_css('figure.attachment--content-restricted')
      expect(page).to have_text('Attachment restricted')
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/content_security_placeholder_restricted.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/content_security_placeholder_restricted.png')
  end

  private

  def capture_docs_screenshot(name, flow:, role:, callouts: [], &)
    BetterTogether::CapybaraScreenshotEngine.capture(
      name,
      device: :both,
      metadata: {
        locale: I18n.default_locale,
        role:,
        feature_set: 'content_security_review_states',
        flow:,
        source_spec: self.class.metadata[:file_path]
      },
      callouts:,
      &
    )
  end

  def create_upload_for(owner, name:, body:, filename:)
    create(:better_together_upload, creator: owner.person, name:).tap do |upload|
      upload.file.attach(io: StringIO.new(body), filename:, content_type: 'text/plain')
      upload.save!
    end
  end

  def create_message_with_attachment(user, filename:)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(png_data),
      filename:,
      content_type: 'image/png'
    )
    attachment_html = ActionText::Attachment.from_attachable(blob).to_html
    conversation = create(:conversation, creator: user.person)
    create(:conversation_participant, conversation:, person: user.person)
    message = create(:message, conversation:, sender: user.person, content: "<p>hello</p>#{attachment_html}")

    [conversation, message, blob]
  end

  def set_restricted!(subject)
    subject.update!(
      lifecycle_state: 'blocked_rejected',
      aggregate_verdict: 'blocked',
      current_visibility_state: 'private',
      current_ai_ingestion_state: 'excluded',
      released_at: nil
    )
  end

  def grant_platform_permission(user, permission_identifier)
    role = create(:better_together_role, :platform_role)
    permission = BetterTogether::ResourcePermission.find_by!(identifier: permission_identifier)
    role.assign_resource_permissions([permission.identifier])
    host_platform.person_platform_memberships.find_or_create_by!(member: user.person, role:)
  end

  def png_data
    # rubocop:disable Layout/LineLength
    "\x89PNG\r\n\x1A\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\b\x06\x00\x00\x00\x1F\x15\xC4\x89\x00\x00\x00\nIDATx\x9Cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xB4\x00\x00\x00\x00IEND\xAEB`\x82".b
    # rubocop:enable Layout/LineLength
  end
end
