# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::PlatformTrustedDomainsController', :as_platform_manager do
  let(:locale) { I18n.default_locale }
  let(:platform) { BetterTogether::Platform.find_by(host: true) }
  let(:role) { BetterTogether::Role.find_by!(identifier: 'community_member') }
  let(:page_html) { Nokogiri::HTML(response.body) }

  def index_path = platform_platform_trusted_domains_path(platform, locale:)

  def valid_params(overrides = {})
    { platform_trusted_domain: { domain: 'Example.ORG', role_id: role.id, enabled: '1',
                                 role_ceiling_confirmed: '1' }.merge(overrides) }
  end

  describe 'GET index and new' do
    it 'lists the domains with stable ids', :aggregate_failures do
      entry = create(:platform_trusted_domain, platform:, domain: 'listed.example.org')
      get index_path

      expect(response).to have_http_status(:ok)
      expect(page_html.at_css("#platform-trusted-domains-table tr##{ActionView::RecordIdentifier.dom_id(entry)}")).to be_present
      expect(page_html.at_css('#new-platform-trusted-domain-btn')).to be_present
      expect(page_html.at_css('#trusted-domains-explanation')).to be_present
    end

    it 'shows the empty state', :aggregate_failures do
      get index_path

      expect(page_html.at_css('#no-trusted-domains')).to be_present
      expect(page_html.at_css('#platform-trusted-domains-table')).to be_nil
    end

    it 'renders the form with labelled fields', :aggregate_failures do
      get new_platform_platform_trusted_domain_path(platform, locale:)

      %w[domain role_id role_ceiling_confirmed include_subdomains public_domain_confirmed enabled note].each do |field|
        expect(page_html.at_css("#platform_trusted_domain_#{field}")).to be_present
        expect(page_html.at_css("label[for=platform_trusted_domain_#{field}]")).to be_present
      end
      expect(page_html.at_css('#platform-trusted-domain-submit-btn')).to be_present
    end
  end

  describe 'platform form Access tab' do
    it 'links to the trusted domains screen', :aggregate_failures do
      create(:platform_trusted_domain, platform:, domain: 'tab.example.org')
      get edit_platform_path(platform, locale:)

      expect(page_html.at_css("##{ActionView::RecordIdentifier.dom_id(platform, 'trusted_domains_list')}").text).to include('tab.example.org')
      expect(page_html.at_css("##{ActionView::RecordIdentifier.dom_id(platform)}_trusted_domains_link")['href']).to eq(index_path)
    end
  end

  describe 'POST create' do
    it 'creates a normalized domain and records the audit event', :aggregate_failures do
      expect { post index_path, params: valid_params }.to change(BetterTogether::PlatformTrustedDomain, :count).by(1)

      expect(response).to redirect_to(index_path)
      entry = platform.platform_trusted_domains.last
      expect(entry.domain).to eq('example.org')
      event = BetterTogether::TrustedDomainEvent.where(event_type: 'domain_added').last
      expect([event.domain, event.via, event.platform_trusted_domain]).to eq(['example.org', 'steward', entry])
    end

    it 'rejects a public mail domain without confirmation', :aggregate_failures do
      expect { post index_path, params: valid_params(domain: 'gmail.com') }
        .not_to change(BetterTogether::PlatformTrustedDomain, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'rejects a role outside the community ceiling', :aggregate_failures do
      steward = BetterTogether::Role.find_by!(identifier: 'platform_manager')

      expect { post index_path, params: valid_params(role_id: steward.id) }
        .not_to change(BetterTogether::PlatformTrustedDomain, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PATCH update and DELETE destroy' do
    let!(:entry) { create(:platform_trusted_domain, platform:, domain: 'edit.example.org') }

    it 'updates and audits', :aggregate_failures do
      patch platform_platform_trusted_domain_path(platform, entry, locale:), params: valid_params(domain: 'edit.example.org',
                                                                                                  enabled: '0')

      expect(response).to redirect_to(index_path)
      expect(entry.reload.enabled).to be(false)
      expect(BetterTogether::TrustedDomainEvent.where(event_type: 'domain_updated').count).to eq(1)
    end

    it 'removes the domain, keeps the audit trail and leaves memberships alone', :aggregate_failures do
      expect { delete platform_platform_trusted_domain_path(platform, entry, locale:) }
        .to change(BetterTogether::PlatformTrustedDomain, :count).by(-1)

      event = BetterTogether::TrustedDomainEvent.find_by(event_type: 'domain_removed')
      expect([event.domain, event.platform_trusted_domain_id]).to eq(['edit.example.org', nil])
    end
  end

  describe 'authorization' do
    it 'denies a signed-out visitor' do
      logout
      get index_path

      expect(response).not_to have_http_status(:ok)
    end
  end
end
