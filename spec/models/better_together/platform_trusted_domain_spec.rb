# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PlatformTrustedDomain do
  let(:platform) { create(:better_together_platform) }
  let(:other_platform) { create(:better_together_platform) }

  def build_domain(**attrs)
    build(:platform_trusted_domain, platform:, **attrs)
  end

  describe 'normalization and validation' do
    it 'lowercases, strips and punycodes the domain', :aggregate_failures do
      expect(build_domain(domain: '  @NLMushrooms.CA ')).to be_valid.and have_attributes(domain: 'nlmushrooms.ca')
      expect(build_domain(domain: 'BÜCHER.example').tap(&:valid?).domain).to eq('xn--bcher-kva.example')
    end

    it 'rejects values that are not domains', :aggregate_failures do
      ['', 'localhost', 'a b.com', 'x@y.com', '.com', 'foo..com'].each do |value|
        expect(build_domain(domain: value)).not_to be_valid
      end
    end

    it 'is unique per platform but independent across platforms', :aggregate_failures do
      create(:platform_trusted_domain, platform:, domain: 'org.example')

      expect(build_domain(domain: 'org.example')).not_to be_valid
      expect(build(:platform_trusted_domain, platform: other_platform, domain: 'org.example')).to be_valid
    end
  end

  describe 'public mail domains' do
    it 'is refused without confirmation and allowed with it', :aggregate_failures do
      expect(build_domain(domain: 'gmail.com')).not_to be_valid
      expect(build_domain(domain: 'gmail.com', public_domain_confirmed: true)).to be_valid
    end
  end

  describe 'role ceiling' do
    let(:facilitator) { BetterTogether::Role.find_by!(identifier: 'community_contributor') }

    it 'defaults to the basic community member role' do
      expect(described_class.new(platform:, domain: 'org.example').tap(&:valid?).role&.identifier)
        .to eq('community_member')
    end

    it 'needs explicit confirmation for any other community role', :aggregate_failures do
      expect(build_domain(role: facilitator)).not_to be_valid
      expect(build_domain(role: facilitator, role_ceiling_confirmed: true)).to be_valid
    end

    it 'never allows management roles, even confirmed' do
      organizer = BetterTogether::Role.find_by!(identifier: 'community_organizer')

      expect(build_domain(role: organizer, role_ceiling_confirmed: true)).not_to be_valid
    end

    it 'rejects platform scoped roles' do
      expect(build_domain(role: create(:better_together_role, :platform_role), role_ceiling_confirmed: true))
        .not_to be_valid
    end
  end

  describe '.match' do
    before { create(:platform_trusted_domain, platform:, domain: 'org.example') }

    it 'matches a verified address on the exact domain, case-insensitively', :aggregate_failures do
      expect(described_class.match(platform:, email: 'Ann@Org.Example', verified: true)).to be_present
      expect(described_class.match(platform:, email: 'ann@other.example', verified: true)).to be_nil
    end

    it 'never matches an unverified address' do
      expect(described_class.match(platform:, email: 'ann@org.example', verified: false)).to be_nil
    end

    it 'does not match subdomains or look-alike suffixes by default', :aggregate_failures do
      expect(described_class.match(platform:, email: 'ann@mail.org.example', verified: true)).to be_nil
      expect(described_class.match(platform:, email: 'ann@evilorg.example', verified: true)).to be_nil
    end

    it 'matches real subdomains only when the flag is on', :aggregate_failures do
      create(:platform_trusted_domain, platform: other_platform, domain: 'sub.example', include_subdomains: true)

      expect(described_class.match(platform: other_platform, email: 'a@x.sub.example', verified: true)).to be_present
      expect(described_class.match(platform: other_platform, email: 'a@notsub.example', verified: true)).to be_nil
    end

    it 'ignores disabled entries and other platforms', :aggregate_failures do
      described_class.where(platform:).update_all(enabled: false) # rubocop:disable Rails/SkipsModelValidations

      expect(described_class.match(platform:, email: 'a@org.example', verified: true)).to be_nil
      expect(described_class.match(platform: other_platform, email: 'a@org.example', verified: true)).to be_nil
    end

    it 'treats the part after the final @ as the host', :aggregate_failures do
      expect(described_class.match(platform:, email: 'org.example@evil.test', verified: true)).to be_nil
      expect(described_class.match(platform:, email: 'not an email', verified: true)).to be_nil
    end
  end

  describe '.lookup' do
    it 'finds the entry for an address without needing verification', :aggregate_failures do
      create(:platform_trusted_domain, platform:, domain: 'org.example')

      expect(described_class.lookup(platform:, email: 'ann@org.example')).to be_present
      expect(described_class.lookup(platform:, email: 'ann@other.example')).to be_nil
      expect(described_class.lookup(platform: nil, email: 'ann@org.example')).to be_nil
    end
  end
end
