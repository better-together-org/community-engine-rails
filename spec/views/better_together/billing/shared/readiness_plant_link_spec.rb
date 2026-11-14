# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/billing/shared/_readiness' do # rubocop:disable RSpec/DescribeClass
  include_context 'with builtin billing processors'

  let(:steward) { find_or_create_test_user("readiness-link-#{SecureRandom.hex(4)}@example.test", 'SecureTest123!@#', :platform_manager) }

  def render_for(owner)
    user = steward
    view.define_singleton_method(:billing_owner) { owner }
    view.define_singleton_method(:current_user) { user }
    render partial: 'better_together/billing/shared/readiness'
  end

  before { BetterTogether::Platform.find_by(host: true).billing_agreement_requirements.destroy_all }

  it 'offers the planting link for the host platform', :aggregate_failures do
    host = BetterTogether::Platform.find_by(host: true)
    BetterTogether::Agreement.where(platform: host).destroy_all

    render_for(host)

    expect(rendered).to include('billing-readiness-plant-agreements-subscription')
  end

  it 'offers no link for a platform that is not the host, since planting targets the host' do
    other = create(:better_together_platform)

    render_for(other)

    expect(rendered).not_to include('billing-readiness-plant-agreements')
  end
end
