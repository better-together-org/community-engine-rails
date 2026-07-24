# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ApplicationHelper do
  around do |example|
    original_providers = BetterTogether.head_tag_providers.dup
    BetterTogether.head_tag_providers = {}
    example.run
  ensure
    BetterTogether.head_tag_providers = original_providers
  end

  describe '#safe_current_user and #safe_current_person' do
    it 'return nil instead of raising when Warden middleware is not present (helper specs have none)' do
      expect(helper.safe_current_user).to be_nil
      expect(helper.safe_current_person).to be_nil
    end
  end

  describe '#current_user_api_token' do
    it 'returns nil instead of raising when Warden middleware is not present' do
      expect(helper.current_user_api_token).to be_nil
    end
  end

  describe '#host_community_primary_email' do
    before { configure_host_platform }

    let(:community) { BetterTogether::Community.find_by!(host: true) }
    let(:contact_detail) { community.contact_detail || create(:contact_detail, contactable: community) }

    it 'returns the primary public host community email address' do
      create(:email_address, contact_detail:, email: 'secondary@example.test', primary_flag: false, privacy: 'public')
      create(:email_address, contact_detail:, email: 'primary@example.test', primary_flag: true, privacy: 'public')

      expect(helper.host_community_primary_email).to eq('primary@example.test')
    end

    it 'falls back to the first public email when no primary public email exists' do
      create(:email_address, contact_detail:, email: 'fallback@example.test', primary_flag: false, privacy: 'public')
      create(:email_address, contact_detail:, email: 'private@example.test', primary_flag: true, privacy: 'private')

      expect(helper.host_community_primary_email).to eq('fallback@example.test')
    end

    it 'returns nil when the host community has no public email addresses' do
      create(:email_address, contact_detail:, email: 'existing-private@example.test', primary_flag: false, privacy: 'private')
      create(:email_address, contact_detail:, email: 'private@example.test', primary_flag: true, privacy: 'private')

      expect(helper.host_community_primary_email).to be_nil
    end
  end

  describe '#base_url' do
    it 'uses the resolved platform primary domain when available' do
      platform_domain = instance_double(BetterTogether::PlatformDomain, url: 'https://primary.example.test')
      platform = instance_double(BetterTogether::Platform,
                                 primary_platform_domain: platform_domain,
                                 resolved_host_url: 'https://primary.example.test')
      Current.platform = platform

      expect(helper.base_url).to eq('https://primary.example.test')
    ensure
      Current.reset
    end
  end

  describe '#storage_proxy_url_for' do
    let(:attachment) { instance_double(ActiveStorage::Attached) }
    let(:request_double) { instance_double(ActionDispatch::Request, base_url: 'https://communityengine.app') }

    before do
      allow(helper).to receive_messages(
        request: request_double,
        default_url_options: { host: 'communityengine.app', protocol: 'https' }
      )
    end

    it 'returns nil when the attachment is blank' do
      expect(helper.storage_proxy_url_for(nil)).to be_nil
    end

    it 'forwards default URL options and keyword arguments to the media URL builder' do
      allow(BetterTogether::MediaUrlBuilder).to receive(:proxy_url_for).and_return(
        'https://communityengine.app/rails/active_storage/proxy/test'
      )

      helper.storage_proxy_url_for(attachment, disposition: 'attachment')

      expect(BetterTogether::MediaUrlBuilder).to have_received(:proxy_url_for).with(
        attachment,
        base_url: 'https://communityengine.app',
        url_options: { host: 'communityengine.app', protocol: 'https' },
        disposition: 'attachment'
      )
      expect(helper.storage_proxy_url_for(attachment, disposition: 'attachment')).to eq(
        'https://communityengine.app/rails/active_storage/proxy/test'
      )
    end
  end

  it 'renders registered provider fragments in order' do
    BetterTogether.register_head_tag_provider(:first, ->(_view_context) { '<meta name="first" />'.html_safe })
    BetterTogether.register_head_tag_provider(:second, ->(_view_context) { '<script src="/test.js"></script>'.html_safe })

    rendered = helper.render_provider_head_tags

    expect(rendered).to include('<meta name="first" />')
    expect(rendered).to include('<script src="/test.js"></script>')
  end

  it 'returns an empty safe buffer when no providers are registered' do
    rendered = helper.render_provider_head_tags

    expect(rendered).to eq('')
    expect(rendered).to be_html_safe
  end

  describe '#contributor_display_visible_for?' do
    let(:page) { build(:better_together_page) }
    let(:policy) { instance_double(BetterTogether::PagePolicy, edit?: editable) }
    let(:editable) { false }

    before do
      policy_double = policy
      allow(page).to receive(:contributors_display_visible?).and_return(false)
      helper.define_singleton_method(:policy) do |_record|
        policy_double
      end
    end

    it 'returns false when contributor display is disabled for non-editors' do
      expect(helper.contributor_display_visible_for?(page)).to be(false)
    end

    context 'when the current viewer can edit the record' do
      let(:editable) { true }

      it 'keeps contributor display visible for editors' do
        expect(helper.contributor_display_visible_for?(page)).to be(true)
      end
    end
  end
end
