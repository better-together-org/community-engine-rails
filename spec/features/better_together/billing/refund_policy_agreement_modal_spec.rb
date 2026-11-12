# frozen_string_literal: true

require 'rails_helper'

# The refund request form reuses the shared agreement modal: the policy box is locked until the policy has been read to the end.
# See .claude/skills/agreement-mechanism/SKILL.md.
RSpec.describe 'Refund request uses the shared agreement modal', :js, :skip_host_setup, retry: 0 do # rubocop:disable RSpec/DescribeClass
  include BetterTogether::CapybaraFeatureHelpers

  include_context 'with offline payment fixtures'
  include_context 'with billing switched on'

  let!(:buyer_user) { find_or_create_test_user('user@example.test') }
  let!(:order) { place_offline('cash') }
  let(:box) { '#billing-refund-policy-accept' }

  before do
    Current.platform = host_platform
    transition.receive(offline_for(order), by: steward)
    purchase_agreements_for(host_platform)
    BetterTogether::Agreement.find_by!(platform: host_platform, identifier: 'refund_policy').update!(lifecycle_state: 'active')
    capybara_login_as_user
    visit "/#{I18n.default_locale}/billing/orders/#{order.id}/refund_requests/new"
  end

  after do
    BetterTogether::Agreement.find_by!(platform: host_platform, identifier: 'refund_policy').update!(lifecycle_state: 'draft')
    Current.platform = nil
  end

  it 'locks the box until the policy has been read in the modal' do
    expect(page).to have_css("#{box}.agreement-checkbox[data-agreement-identifier='refund_policy']", visible: :all)

    find('#billing-refund-policy-view').click
    expect(page).to have_css('#agreementModal.show #agreement_modal_frame', wait: 10)
    page.execute_script(<<~JS)
      (function() {
        const body = document.getElementById('agreement_modal_frame').closest('.modal-body');
        body.scrollTop = body.scrollHeight;
        body.dispatchEvent(new Event('scroll', { bubbles: true }));
      })();
    JS

    expect(page).to have_css("#{box}[data-better-together-agreement-enabled='true']", visible: :all, wait: 10)
  end
end
