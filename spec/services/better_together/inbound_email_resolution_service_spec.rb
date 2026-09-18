# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::InboundEmailResolutionService do
  def address(value)
    Mail::Address.new(value)
  end

  def create_tenant(community:, domain:)
    platform = create(:better_together_platform, community:, host_url: "https://#{domain}")
    platform.platform_domains.find_or_create_by!(hostname: domain) do |platform_domain|
      platform_domain.primary = true
      platform_domain.active = true
    end

    platform
  end

  def issue_token(recipient:, platform:, repliable: nil)
    BetterTogether::InboundEmailReplyToken.issue!(
      recipient:,
      repliable: repliable || create(:better_together_post),
      notification_type: 'comment_added',
      platform:
    )
  end

  def trusted_authserv_id
    'mail.communityengine.app'
  end

  def raw_mail(to:, from:, extra_headers: [])
    Mail.new(<<~MAIL)
      From: #{from}
      To: #{to}
      Subject: Test
      #{extra_headers.join("\n")}
      Content-Type: text/plain

      Body
    MAIL
  end

  it 'returns a tenant-scoped community resolution for mapped domains' do
    community = create(:better_together_community, name: 'Tenant Resolution Community')
    platform = create_tenant(community:, domain: 'tenant-resolution.example.test')

    resolution = described_class.new(address("community+#{community.slug}@tenant-resolution.example.test")).resolve

    expect(resolution.route_kind).to eq('community')
    expect(resolution.platform).to eq(platform)
    expect(resolution.target).to eq(community)
  end

  it 'returns unresolved for community aliases on the wrong tenant domain' do
    first_community = create(:better_together_community, name: 'First Tenant')
    platform = create_tenant(community: first_community, domain: 'tenant-one.example.test')
    second_community = create(:better_together_community, name: 'Second Tenant')
    create_tenant(community: second_community, domain: 'tenant-two.example.test')

    resolution = described_class.new(address("community+#{second_community.slug}@tenant-one.example.test")).resolve

    expect(resolution.route_kind).to eq('unresolved')
    expect(resolution.platform).to eq(platform)
    expect(resolution.target).to be_nil
  end

  describe 'agent+ resolution with authentication hardening' do
    before { stub_const('BetterTogether::InboundMailAuthentication::TRUSTED_AUTHSERV_ID', trusted_authserv_id) }

    it 'resolves when the address matches and no mail is provided (back-compat with pre-hardening callers)' do
      community = create(:better_together_community, name: 'Agent Auth Tenant Nomail')
      platform = create_tenant(community:, domain: 'tenant-agent-nomail.example.test')
      person = create(:better_together_person, identifier: 'agent-nomail')
      create(:better_together_person_platform_membership, member: person, joinable: platform, status: 'active')

      resolution = described_class.new(
        address('agent+agent-nomail@tenant-agent-nomail.example.test'),
        sender: address(person.email)
      ).resolve

      expect(resolution.route_kind).to eq('agent')
      expect(resolution.target).to eq(person)
    end

    it 'resolves when the address matches and DKIM/DMARC are merely absent (most domains do not publish them)' do
      community = create(:better_together_community, name: 'Agent Auth Tenant Absent')
      platform = create_tenant(community:, domain: 'tenant-agent-absent.example.test')
      person = create(:better_together_person, identifier: 'agent-absent')
      create(:better_together_person_platform_membership, member: person, joinable: platform, status: 'active')
      mail = raw_mail(to: 'agent+agent-absent@tenant-agent-absent.example.test', from: person.email)

      resolution = described_class.new(
        address('agent+agent-absent@tenant-agent-absent.example.test'),
        sender: address(person.email),
        mail:
      ).resolve

      expect(resolution.route_kind).to eq('agent')
      expect(resolution.target).to eq(person)
    end

    it 'rejects when the address matches but a trusted DKIM result explicitly failed' do
      community = create(:better_together_community, name: 'Agent Auth Tenant Dkim Fail')
      platform = create_tenant(community:, domain: 'tenant-agent-dkim-fail.example.test')
      person = create(:better_together_person, identifier: 'agent-dkim-fail')
      create(:better_together_person_platform_membership, member: person, joinable: platform, status: 'active')
      mail = raw_mail(
        to: 'agent+agent-dkim-fail@tenant-agent-dkim-fail.example.test',
        from: person.email,
        extra_headers: ["Authentication-Results: #{trusted_authserv_id}; dkim=fail"]
      )

      resolution = described_class.new(
        address('agent+agent-dkim-fail@tenant-agent-dkim-fail.example.test'),
        sender: address(person.email),
        mail:
      ).resolve

      expect(resolution.route_kind).to eq('unresolved')
      expect(resolution.target).to be_nil
    end

    it 'rejects when the address matches but a trusted SPF result explicitly failed' do
      community = create(:better_together_community, name: 'Agent Auth Tenant Spf Fail')
      platform = create_tenant(community:, domain: 'tenant-agent-spf-fail.example.test')
      person = create(:better_together_person, identifier: 'agent-spf-fail')
      create(:better_together_person_platform_membership, member: person, joinable: platform, status: 'active')
      mail = raw_mail(
        to: 'agent+agent-spf-fail@tenant-agent-spf-fail.example.test',
        from: person.email,
        extra_headers: ['Received-SPF: Fail (mailfrom) identity=mailfrom']
      )

      resolution = described_class.new(
        address('agent+agent-spf-fail@tenant-agent-spf-fail.example.test'),
        sender: address(person.email),
        mail:
      ).resolve

      expect(resolution.route_kind).to eq('unresolved')
    end

    it 'still resolves on SPF softfail (does not over-block common legitimate configurations)' do
      community = create(:better_together_community, name: 'Agent Auth Tenant Softfail')
      platform = create_tenant(community:, domain: 'tenant-agent-softfail.example.test')
      person = create(:better_together_person, identifier: 'agent-softfail')
      create(:better_together_person_platform_membership, member: person, joinable: platform, status: 'active')
      mail = raw_mail(
        to: 'agent+agent-softfail@tenant-agent-softfail.example.test',
        from: person.email,
        extra_headers: ['Received-SPF: Softfail (mailfrom) identity=mailfrom']
      )

      resolution = described_class.new(
        address('agent+agent-softfail@tenant-agent-softfail.example.test'),
        sender: address(person.email),
        mail:
      ).resolve

      expect(resolution.route_kind).to eq('agent')
      expect(resolution.target).to eq(person)
    end

    it 'ignores a forged Authentication-Results header with the wrong authserv-id' do
      community = create(:better_together_community, name: 'Agent Auth Tenant Forged')
      platform = create_tenant(community:, domain: 'tenant-agent-forged.example.test')
      person = create(:better_together_person, identifier: 'agent-forged')
      create(:better_together_person_platform_membership, member: person, joinable: platform, status: 'active')
      # A real hard-fail from the trusted authserv-id, plus a forged "pass" an attacker could
      # have injected themselves -- the forged instance must not override the real failure.
      mail = raw_mail(
        to: 'agent+agent-forged@tenant-agent-forged.example.test',
        from: person.email,
        extra_headers: [
          'Authentication-Results: attacker-controlled-id; dkim=pass',
          "Authentication-Results: #{trusted_authserv_id}; dkim=fail"
        ]
      )

      resolution = described_class.new(
        address('agent+agent-forged@tenant-agent-forged.example.test'),
        sender: address(person.email),
        mail:
      ).resolve

      expect(resolution.route_kind).to eq('unresolved')
    end
  end

  describe 'reply+ resolution' do
    it 'resolves a reply token when the sender matches the recipient' do
      community = create(:better_together_community, name: 'Reply Tenant')
      platform = create_tenant(community:, domain: 'tenant-reply.example.test')
      person = create(:better_together_person)
      token = issue_token(recipient: person, platform:)

      resolution = described_class.new(
        address(token.reply_address('tenant-reply.example.test')),
        sender: address(person.email)
      ).resolve

      expect(resolution.route_kind).to eq('reply')
      expect(resolution.target).to eq(token)
    end

    it 'rejects a reply token when the sender does not match the recipient' do
      community = create(:better_together_community, name: 'Reply Tenant Guard')
      platform = create_tenant(community:, domain: 'tenant-reply-guard.example.test')
      person = create(:better_together_person)
      token = issue_token(recipient: person, platform:)

      resolution = described_class.new(
        address(token.reply_address('tenant-reply-guard.example.test')),
        sender: address('someone-else@example.test')
      ).resolve

      expect(resolution.route_kind).to eq('unresolved')
      expect(resolution.target).to be_nil
    end

    it 'rejects an already-consumed reply token' do
      community = create(:better_together_community, name: 'Reply Tenant Consumed')
      platform = create_tenant(community:, domain: 'tenant-reply-consumed.example.test')
      person = create(:better_together_person)
      token = issue_token(recipient: person, platform:)
      token.consume!

      resolution = described_class.new(
        address(token.reply_address('tenant-reply-consumed.example.test')),
        sender: address(person.email)
      ).resolve

      expect(resolution.route_kind).to eq('unresolved')
      expect(resolution.target).to be_nil
    end

    it 'rejects an unknown token value' do
      community = create(:better_together_community, name: 'Reply Tenant Unknown')
      create_tenant(community:, domain: 'tenant-reply-unknown.example.test')

      resolution = described_class.new(
        address('reply+not-a-real-token@tenant-reply-unknown.example.test'),
        sender: address('anyone@example.test')
      ).resolve

      expect(resolution.route_kind).to eq('unresolved')
      expect(resolution.target).to be_nil
    end

    it 'rejects a reply token when the sender matches but a trusted DKIM result explicitly failed' do
      stub_const('BetterTogether::InboundMailAuthentication::TRUSTED_AUTHSERV_ID', trusted_authserv_id)
      community = create(:better_together_community, name: 'Reply Tenant Dkim Fail')
      platform = create_tenant(community:, domain: 'tenant-reply-dkim-fail.example.test')
      person = create(:better_together_person)
      token = issue_token(recipient: person, platform:)
      mail = raw_mail(
        to: token.reply_address('tenant-reply-dkim-fail.example.test'),
        from: person.email,
        extra_headers: ["Authentication-Results: #{trusted_authserv_id}; dkim=fail"]
      )

      resolution = described_class.new(
        address(token.reply_address('tenant-reply-dkim-fail.example.test')),
        sender: address(person.email),
        mail:
      ).resolve

      expect(resolution.route_kind).to eq('unresolved')
      expect(resolution.target).to be_nil
    end

    it 'rejects a reply token issued for a different tenant platform' do
      community_a = create(:better_together_community, name: 'Reply Tenant A')
      platform_a = create_tenant(community: community_a, domain: 'tenant-reply-a.example.test')
      community_b = create(:better_together_community, name: 'Reply Tenant B')
      create_tenant(community: community_b, domain: 'tenant-reply-b.example.test')
      person = create(:better_together_person)
      token = issue_token(recipient: person, platform: platform_a)

      resolution = described_class.new(
        address(token.reply_address('tenant-reply-b.example.test')),
        sender: address(person.email)
      ).resolve

      expect(resolution.route_kind).to eq('unresolved')
      expect(resolution.target).to be_nil
    end
  end
end
