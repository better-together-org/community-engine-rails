# frozen_string_literal: true

require 'rails_helper'

# Stable ids on the membership lifecycle controls, used by docs screenshots and feature specs.
RSpec.describe 'Membership lifecycle DOM contract', :as_platform_manager, type: :request do # rubocop:disable RSpec/DescribeClass
  let!(:platform) { BetterTogether::Platform.find_by(host: true) || configure_host_platform }
  let(:role) { BetterTogether::Role.find_by!(identifier: 'platform_analytics_viewer') }
  let(:person) { create(:better_together_person, platform_id: platform.id) }
  let!(:membership) do
    BetterTogether::PersonPlatformMembership.create!(member: person, joinable: platform, role:, status: 'active',
                                                     source: 'invitation')
  end
  let(:page_html) { Nokogiri::HTML(response.body) }

  it 'gives each member card its status, source, dates and actions', :aggregate_failures do
    get better_together.platform_person_platform_memberships_path(platform, locale: I18n.default_locale)

    %i[lifecycle status source dates actions].each do |part|
      expect(page_html.css("##{ActionView::RecordIdentifier.dom_id(membership, part)}").size).to eq(1), part.to_s
    end
    expect(page_html.css("##{ActionView::RecordIdentifier.dom_id(membership, :status)}").text).to include('Current')
    expect(page_html.css("##{ActionView::RecordIdentifier.dom_id(membership, :end_form)}").size).to eq(1)
    expect(page_html.css("##{ActionView::RecordIdentifier.dom_id(membership, :suspend_form)}").size).to eq(1)
  end

  it 'asks for confirmation before ending or suspending', :aggregate_failures do
    get better_together.platform_person_platform_memberships_path(platform, locale: I18n.default_locale)

    %i[end_form suspend_form].each do |form|
      node = page_html.at_css("##{ActionView::RecordIdentifier.dom_id(membership, form)}")
      expect(node['data-turbo-confirm']).to be_present, form.to_s
    end
  end

  it 'offers reinstate instead of suspend once suspended', :aggregate_failures do
    membership.suspend!(actor: nil)
    get better_together.platform_person_platform_memberships_path(platform, locale: I18n.default_locale)

    expect(page_html.css("##{ActionView::RecordIdentifier.dom_id(membership, :reinstate_form)}").size).to eq(1)
    expect(page_html.css("##{ActionView::RecordIdentifier.dom_id(membership, :suspend_form)}").size).to eq(0)
    reinstate = page_html.at_css("##{ActionView::RecordIdentifier.dom_id(membership, :reinstate_form)}")
    expect(reinstate['data-turbo-confirm']).to be_present
  end

  %w[en fr es uk].each do |locale|
    it "localizes every confirm message in #{locale}", :aggregate_failures do
      membership.suspend!(actor: nil)
      get better_together.platform_person_platform_memberships_path(platform.id, locale:)
      confirms = page_html.css('[data-turbo-confirm]').map { |node| node['data-turbo-confirm'] }

      expect(response).to have_http_status(:ok)
      expect(confirms.size).to be >= 3
      expect(confirms).to all(satisfy { |text| text.exclude?('translation missing') })
      expect(confirms.uniq.size).to eq(confirms.size)
    end
  end

  it 'warns in the confirm when it is the only current membership', :aggregate_failures do
    get better_together.platform_person_platform_memberships_path(platform, locale: I18n.default_locale)

    %i[end_form suspend_form].each do |form|
      node = page_html.at_css("##{ActionView::RecordIdentifier.dom_id(membership, form)}")
      expect(node['data-turbo-confirm']).to include('only current membership'), form.to_s
    end
  end

  it 'does not warn when the member holds another current membership here', :aggregate_failures do
    other_role = BetterTogether::Role.find_by!(identifier: 'platform_member')
    BetterTogether::PersonPlatformMembership.create!(member: person, joinable: platform, role: other_role,
                                                     status: 'active')
    get better_together.platform_person_platform_memberships_path(platform, locale: I18n.default_locale)

    node = page_html.at_css("##{ActionView::RecordIdentifier.dom_id(membership, :end_form)}")
    expect(node['data-turbo-confirm']).not_to include('only current membership')
  end
end
