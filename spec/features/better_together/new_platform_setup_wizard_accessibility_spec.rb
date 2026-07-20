# frozen_string_literal: true

require 'rails_helper'

# Accessibility coverage for the new_platform_setup wizard, per
# docs/development/accessibility_testing.md — modeled on reports_accessibility_spec.rb.
# This description matches /setup wizard/, which makes
# automatic_test_configuration.rb skip its usual auto-login/auto-host-setup,
# so both are done explicitly below instead.
RSpec.describe 'New platform setup wizard accessibility', :accessibility, :as_platform_manager, :js, retry: 0 do
  let(:supported_locales) { I18n.available_locales }
  let(:base_i18n_key) { 'better_together.wizard_step_definitions.new_platform_setup' }

  before do
    configure_host_platform
    capybara_login_as_platform_manager
  end

  # rubocop:disable RSpec/NoExpectationExample -- expectations live in the shared
  # check_step_accessibility helper (called once per step, per locale, below),
  # not inline in this example body.
  it 'passes WCAG 2.1 AA accessibility checks on every step, in every supported locale, ' \
     'and keeps the progress list in sync with the active step',
     :aggregate_failures do
    supported_locales.each do |locale|
      run_full_wizard_flow(locale)
    end
  end
  # rubocop:enable RSpec/NoExpectationExample

  it 'connects field help text to its input via aria-describedby on platform_identity and domain, ' \
     'in every supported locale',
     :aggregate_failures do
    supported_locales.each do |locale|
      visit_new_platform_setup(locale)
      advance_past_welcome

      expect(find('#new_platform_platform_name', visible: :all)['aria-describedby'])
        .to eq('new_platform_platform_name_help')
      expect(find('#new_platform_platform_description', visible: :all)['aria-describedby'])
        .to eq('new_platform_platform_description_help')
      expect(find('#new_platform_platform_host_url', visible: :all)['aria-describedby'])
        .to eq('new_platform_platform_host_url_help')
      expect(find('#new_platform_platform_privacy', visible: :all)['aria-describedby'])
        .to eq('new_platform_platform_privacy_help')
      expect(find('#new_platform_platform_time_zone', visible: :all)['aria-describedby'])
        .to eq('new_platform_platform_time_zone_help')

      fill_in_platform_identity_and_submit

      expect(find('#new_platform_domain_hostname', visible: :all)['aria-describedby'])
        .to eq('new_platform_domain_hostname_help')
    end
  end

  it "gives each review_and_launch recap section's edit link a distinct, descriptive accessible name " \
     '(never a bare "Edit")' do
    drive_to_review_and_launch(I18n.default_locale)

    expected_edit_texts = %w[platform_identity domain steward_account invited_members].map do |section|
      I18n.t("#{base_i18n_key}.review_and_launch.sections.#{section}.edit", locale: I18n.default_locale)
    end

    edit_links = page.all('a', text: /\AEdit /)
    edit_link_texts = edit_links.map(&:text)

    expect(edit_link_texts).to match_array(expected_edit_texts)
    expect(edit_link_texts).not_to include('Edit')
    expect(edit_link_texts.uniq.length).to eq(edit_link_texts.length)
  end

  def visit_new_platform_setup(locale)
    visit better_together.new_platform_setup_path(locale:)
    expect(page).to have_css('main form', wait: 10, visible: :all)
  end

  def click_submit
    find('input[type="submit"]', match: :first).click
  end

  def advance_past_welcome
    click_submit
    expect(page).to have_css('#new_platform_platform_name', wait: 10, visible: :all)
  end

  # rubocop:todo Metrics/AbcSize
  def fill_in_platform_identity_and_submit(suffix: SecureRandom.hex(4))
    fill_in 'new_platform_platform_name', with: "Tenant Platform #{suffix}"
    fill_in 'new_platform_platform_description', with: 'A place where neighbors and friends support each other.'
    fill_in 'new_platform_platform_host_url', with: "https://tenant-#{suffix}.example.com"
    click_submit
    expect(page).to have_css('#new_platform_domain_hostname', wait: 10, visible: :all)
  end
  # rubocop:enable Metrics/AbcSize

  def skip_domain_step
    find('button[name="skip_step"]').click
    expect(page).to have_css('#new_platform_steward_email', wait: 10, visible: :all)
  end

  def fill_in_steward_account_and_submit(suffix: SecureRandom.hex(4))
    fill_in 'new_platform_steward_email', with: "steward-#{suffix}@example.com"
    fill_in 'new_platform_steward_password', with: '!StrongPass12345?'
    fill_in 'new_platform_steward_password_confirmation', with: '!StrongPass12345?'
    fill_in 'new_platform_steward_person_name', with: 'New Platform Steward'
    fill_in 'new_platform_steward_person_identifier', with: "steward-#{suffix}"
    fill_in 'new_platform_steward_person_description', with: 'First steward of this new platform.'
    click_submit
    # 'main' exists on this page too, so waiting for it doesn't confirm
    # navigation happened — wait on the actual URL instead.
    expect(page).to have_current_path(%r{/invite_members\z}, wait: 10)
  end

  def skip_invite_members_step
    find('button[name="skip_step"]').click
    expect(page).to have_current_path(%r{/review_and_launch\z}, wait: 10)
  end

  def drive_to_review_and_launch(locale, suffix: SecureRandom.hex(4))
    visit_new_platform_setup(locale)
    advance_past_welcome
    fill_in_platform_identity_and_submit(suffix:)
    skip_domain_step
    fill_in_steward_account_and_submit(suffix:)
    skip_invite_members_step
  end

  # Runs axe against every step's rendered page and confirms the progress
  # step list's aria-current="step" tracks the active step, in the given
  # locale — the shared body for the primary "every step, every locale" spec.
  # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
  def run_full_wizard_flow(locale)
    suffix = SecureRandom.hex(4)

    visit_new_platform_setup(locale)
    check_step_accessibility('welcome', locale)
    advance_past_welcome

    check_step_accessibility('platform_identity', locale)
    fill_in_platform_identity_and_submit(suffix:)

    check_step_accessibility('domain', locale)
    skip_domain_step

    check_step_accessibility('steward_account', locale)
    fill_in_steward_account_and_submit(suffix:)

    check_step_accessibility('invite_members', locale)
    skip_invite_members_step

    check_step_accessibility('review_and_launch', locale)
    click_submit
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  def check_step_accessibility(identifier, locale)
    expect(page).to be_axe_clean.within('main').according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)

    expected_step_name = I18n.t("#{base_i18n_key}.#{identifier}.progress.step_name", locale:)
    expect(find('li[aria-current="step"]').text.strip).to eq(expected_step_name)
  end
end
