# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for agreement flows',
               :docs_screenshot,
               :js,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let!(:host_platform) { configure_host_platform }
  let!(:terms_of_service) { BetterTogether::Agreement.find_by!(identifier: 'terms_of_service') }
  let!(:privacy_policy) { BetterTogether::Agreement.find_by!(identifier: 'privacy_policy') }
  let!(:code_of_conduct) { BetterTogether::Agreement.find_by!(identifier: 'code_of_conduct') }
  let!(:content_publishing_agreement) do
    BetterTogether::Agreement.find_by!(identifier: BetterTogether::PublicVisibilityGate::AGREEMENT_IDENTIFIER)
  end
  let!(:pending_user) do
    create(:user, :confirmed, email: "agreements-pending-#{SecureRandom.hex(4)}@example.test", password: 'SecureTest123!@#')
  end
  let!(:publisher_user) do
    find_or_create_test_user("agreements-publisher-#{SecureRandom.hex(4)}@example.test", 'SecureTest123!@#', :platform_manager)
  end
  let!(:publisher_person) { publisher_user.person }
  let!(:joatu_participant_user) do
    create(:user,
           :confirmed,
           email: "agreements-joatu-#{SecureRandom.hex(4)}@example.test",
           password: 'SecureTest123!@#')
  end
  let!(:joatu_offer_creator) do
    create(:person, name: 'Offer Steward', identifier: "offer-steward-#{SecureRandom.hex(3)}")
  end
  let!(:joatu_request_creator) do
    create(:person, name: 'Request Steward', identifier: "request-steward-#{SecureRandom.hex(3)}")
  end
  let!(:joatu_offer) do
    create(:better_together_joatu_offer,
           name: 'Laptop Repair Help',
           creator: joatu_offer_creator,
           privacy: 'public')
  end
  let!(:joatu_request) do
    create(:better_together_joatu_request,
           name: 'Need Laptop Repair',
           creator: joatu_request_creator,
           privacy: 'public',
           target: joatu_offer.target)
  end
  let!(:joatu_agreement) do
    create(:better_together_joatu_agreement,
           offer: joatu_offer,
           request: joatu_request,
           status: :pending)
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    host_platform.update!(requires_invitation: false, privacy: 'public')
    BetterTogether::AgreementBuilder.seed_data
    joatu_participant_user.update!(person: joatu_offer_creator)
    accept_required_registration_agreements_for(publisher_user.person)
    accept_required_registration_agreements_for(joatu_participant_user.person)
    publisher_user.person.agreement_participants.where(agreement: content_publishing_agreement).delete_all
  end

  it 'captures the registration agreement entry screen' do
    capture_docs_screenshot('agreement_registration_form', role: 'public', flow: 'registration') do
      visit new_user_registration_path(locale: I18n.default_locale)

      expect(page).to have_text('Sign Up', wait: 10)
      expect(page).to have_text('Terms of Service')
      expect(page).to have_text('Privacy Policy')
      expect(page).to have_text('Code of Conduct')
    end
  end

  it 'captures the registration agreement review modal' do
    capture_docs_screenshot('agreement_registration_modal', role: 'public', flow: 'registration') do
      visit new_user_registration_path(locale: I18n.default_locale)

      find('.agreement-modal-link', text: 'View', match: :first).click

      expect(page).to have_css('#agreementModal.show', wait: 10)
      expect(page).to have_css('#agreement_modal_frame', wait: 10)
      expect(page).to have_text('Terms of Service', wait: 10)
    end
  end

  it 'captures the agreements status review screen' do
    capture_docs_screenshot('agreement_status_pending', role: 'user', flow: 'agreements_status') do
      capybara_sign_in_user(pending_user.email, 'SecureTest123!@#')
      visit agreements_status_path(locale: I18n.default_locale)

      expect(page).to have_text('Review Required Agreements', wait: 10)
      expect(page).to have_text('Required')
      expect(page).to have_text('Terms of Service')
      expect(page).to have_text('I have read and accept this agreement')
    end
  end

  it 'captures the publish-blocked form with direct agreement launch' do
    capture_docs_screenshot('agreement_publish_blocked_form', role: 'publisher', flow: 'first_publish') do
      capybara_sign_in_user(publisher_user.email, 'SecureTest123!@#')
      visit new_community_path(locale: I18n.default_locale)

      fill_in 'community[name_en]', with: 'Agreement Review Community'
      fill_in_action_text_hidden_input('community[description_html_en]', 'A public community pending publishing consent.')
      select_model_privacy('public')

      find("input[type='submit'][value='Create Community'], button[type='submit']", match: :first).click

      expect(page).to have_text('The content publishing agreement must be accepted before this can be made public.', wait: 10)
      expect(page).to have_css('.agreement-modal-link[data-agreement-mode="direct_accept"]', wait: 10)
      expect(page).to have_text('Review and accept the content publishing agreement')
    end
  end

  it 'captures the publishing agreement modal before review completion' do
    capture_docs_screenshot('agreement_publish_modal_locked', role: 'publisher', flow: 'first_publish') do
      open_blocked_publish_modal

      expect(page).to have_css('#agreementModal.show', wait: 10)
      expect(page).to have_button('I agree', wait: 10)
      expect(page).to have_button('Cancel', wait: 10)
    end
  end

  it 'captures the publishing agreement modal after review completion' do
    capture_docs_screenshot('agreement_publish_modal_ready', role: 'publisher', flow: 'first_publish') do
      open_blocked_publish_modal
      scroll_agreement_modal_to_end

      expect(page).to have_button('I agree', wait: 10)
      expect(page).to have_text('Agreement', wait: 10)
    end
  end

  it 'captures the JOATU agreement details screen' do
    capture_docs_screenshot('agreement_joatu_show', role: 'participant', flow: 'joatu') do
      capybara_sign_in_user(joatu_participant_user.email, 'SecureTest123!@#')
      visit joatu_agreement_path(joatu_agreement, locale: I18n.default_locale)

      expect(page).to have_text('Agreement', wait: 10)
      expect(page).to have_text('pending')
      expect(page).to have_text('Participants')
      expect(page).to have_button('Accept')
      expect(page).to have_button('Reject')
    end
  end

  private

  def capture_docs_screenshot(slug, role:, flow:, &)
    result = BetterTogether::CapybaraScreenshotEngine.capture(
      slug,
      device: :both,
      metadata: {
        locale: I18n.default_locale,
        role:,
        flow:,
        source_spec: self.class.metadata[:file_path]
      },
      &
    )

    expect(result[:desktop]).to end_with("docs/screenshots/desktop/#{slug}.png")
    expect(result[:mobile]).to end_with("docs/screenshots/mobile/#{slug}.png")
  end

  # rubocop:todo Metrics/MethodLength
  def fill_in_action_text_hidden_input(field_name, value)
    page.execute_script(<<~JS, field_name, value)
      (function(targetName, content) {
        const input = document.querySelector(`input[name="${targetName}"]`);
        if (!input) return;
        input.value = content;
        input.dispatchEvent(new Event('input', { bubbles: true }));
        input.dispatchEvent(new Event('change', { bubbles: true }));

        const editor = document.querySelector(`trix-editor[input="${input.id}"]`);
        if (editor) {
          editor.editor.loadHTML(content);
          editor.dispatchEvent(new Event('input', { bubbles: true }));
          editor.dispatchEvent(new Event('change', { bubbles: true }));
        }
      })(arguments[0], arguments[1]);
    JS
  end
  # rubocop:enable Metrics/MethodLength

  def select_model_privacy(value)
    page.execute_script(<<~JS, value)
      (function(targetValue) {
        const select = document.querySelector("select[name$='[privacy]']");
        if (!select) return;
        select.value = targetValue;
        select.dispatchEvent(new Event('input', { bubbles: true }));
        select.dispatchEvent(new Event('change', { bubbles: true }));
      })(arguments[0]);
    JS
  end

  # rubocop:todo Metrics/AbcSize
  def open_blocked_publish_modal
    capybara_sign_in_user(publisher_user.email, 'SecureTest123!@#')
    visit new_community_path(locale: I18n.default_locale)

    expect(page).to have_field('community[name_en]', wait: 10)
    fill_in 'community[name_en]', with: 'Agreement Review Community'
    fill_in_action_text_hidden_input('community[description_html_en]', 'A public community pending publishing consent.')
    select_model_privacy('public')

    find("input[type='submit'][value='Create Community'], button[type='submit']", match: :first).click

    expect(page).to have_css('.agreement-modal-link[data-agreement-mode="direct_accept"]', wait: 10)
    find('.agreement-modal-link[data-agreement-mode="direct_accept"]', match: :first).click
    expect(page).to have_css('#agreementModal.show', wait: 10)
    expect(page).to have_css('#agreement_modal_frame', wait: 10)
    expect(page).to have_text('Agreement', wait: 10)
    expect(page).to have_button('I agree', wait: 10)
  end
  # rubocop:enable Metrics/AbcSize

  # rubocop:todo Metrics/MethodLength
  def scroll_agreement_modal_to_end
    Selenium::WebDriver::Wait.new(timeout: 10).until do
      page.evaluate_script(<<~JS)
        (function() {
          const frame = document.getElementById('agreement_modal_frame');
          const modalBody = frame && frame.closest('.modal-body');
          return !!modalBody && modalBody.scrollHeight > 0;
        })();
      JS
    end

    page.execute_script(<<~JS)
      (function() {
        const frame = document.getElementById('agreement_modal_frame');
        const modalBody = frame && frame.closest('.modal-body');
        if (!modalBody) return;
        modalBody.scrollTop = modalBody.scrollHeight;
        modalBody.dispatchEvent(new Event('scroll', { bubbles: true }));
      })();
    JS
  end
  # rubocop:enable Metrics/MethodLength

  def accept_required_registration_agreements_for(person)
    BetterTogether::Agreement.registration_consent_records.each do |agreement|
      BetterTogether::AgreementAcceptanceRecorder.record!(
        agreement: agreement,
        participant: person,
        acceptance_method: :agreement_review,
        accepted_at: Time.current,
        context: { flow: 'docs_screenshot_seed' }
      )
    end
  end
end
