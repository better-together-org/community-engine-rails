# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Platform integrations and custom code accessibility', # rubocop:disable RSpec/DescribeClass
               :accessibility, :js, :skip_host_setup, retry: 0 do
  include BetterTogether::CapybaraFeatureHelpers

  let(:host_platform) { configure_host_platform }
  let(:wcag) { %i[wcag2a wcag2aa wcag21a wcag21aa] }

  before do
    BetterTogether::PlatformSettingsRegistry.reset!
    BetterTogether.register_platform_setting('axe_sample.token', label: 'Sample token', hint: 'Hint text')
    BetterTogether.register_platform_setting('axe_sample.enabled', type: :boolean, label: 'Sample switch')
    Current.platform = host_platform
    capybara_login_as_platform_manager
    person = BetterTogether::User.find_by!(email: 'manager@example.test').person
    host_platform.person_platform_memberships.find_or_create_by!(
      member: person, role: BetterTogether::Role.find_by!(identifier: 'platform_code_manager'), status: 'active'
    )
    BetterTogether::PlatformSnippet.find_or_create_by!(platform: host_platform, name: 'Axe tracker') do |s|
      s.assign_attributes(location: 'head_end', kind: 'script_inline', content: 'window.axe = true;')
    end
    person.expire_permission_cache!
  end

  after do
    BetterTogether::PlatformSettingsRegistry.reset!
    Current.platform = nil
  end

  it 'passes WCAG 2.1 AA on the Integrations tab in each locale', :aggregate_failures do
    I18n.available_locales.each do |locale|
      visit better_together.edit_platform_path(host_platform, locale:)
      find('#platform-integrations-tab').click
      expect(page).to have_css('#platform-integrations', visible: :visible, wait: 10)
      expect(page).to be_axe_clean.within('#platform-integrations').according_to(*wcag)
    end
  end
end
