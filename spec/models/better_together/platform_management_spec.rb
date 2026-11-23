# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PlatformManagement do
  def operator(**attrs)
    create(:better_together_platform, type: 'BetterTogether::OperatorPlatform', **attrs)
  end

  def hosted
    create(:better_together_platform, type: 'BetterTogether::HostedPlatform')
  end

  def edge(operator_side, managed, **attrs)
    create(:better_together_platform_management, :active, operator_platform: operator_side, managed_platform: managed, **attrs)
  end

  def build_derived(**attrs)
    build(:better_together_platform_management, :active,
          { operator_platform: bts, managed_platform: site, delegated_from: host_over_site,
            granted_scopes: %w[read] }.merge(attrs))
  end

  let(:steward) { create(:better_together_person) }

  describe 'validations' do
    it 'builds a valid requested edge and mirrors the managed platform' do
      record = build(:better_together_platform_management)
      expect(record).to be_valid
      expect(record.platform_id).to eq(record.managed_platform_id)
      expect(record).to be_requested
    end

    it 'rejects an operator that is not an OperatorPlatform' do
      record = build(:better_together_platform_management, operator_platform: hosted)
      expect(record).not_to be_valid
      expect(record.errors[:operator_platform]).to be_present
    end

    it 'rejects a managed platform that is federated or oauth' do
      record = build(:better_together_platform_management,
                     managed_platform: create(:better_together_platform, :remote, type: 'BetterTogether::FederatedPlatform'),
                     transport: 'http')
      expect(record).not_to be_valid
      expect(record.errors[:managed_platform]).to be_present
    end

    it 'allows an operator platform to be managed' do
      expect(build(:better_together_platform_management, managed_platform: operator)).to be_valid
    end

    it 'rejects a self edge' do
      op = operator
      expect(build(:better_together_platform_management, operator_platform: op, managed_platform: op)).not_to be_valid
    end

    it 'enforces one edge per operator and managed pair' do
      first = edge(operator, hosted)
      dup = build(:better_together_platform_management, operator_platform: first.operator_platform,
                                                        managed_platform: first.managed_platform)
      expect(dup).not_to be_valid
    end

    it 'rejects unknown and empty scopes' do
      expect(build(:better_together_platform_management, granted_scopes: %w[root])).not_to be_valid
      expect(build(:better_together_platform_management, granted_scopes: [])).not_to be_valid
    end

    it 'rejects an unknown status' do
      expect(build(:better_together_platform_management, status: 'bogus')).not_to be_valid
    end

    it 'requires http transport for a remote operator and direct for local platforms' do
      expect(build(:better_together_platform_management, :remote_operator)).to be_valid
      expect(build(:better_together_platform_management, :remote_operator, transport: 'direct')).not_to be_valid
      expect(build(:better_together_platform_management, transport: 'http')).not_to be_valid
    end

    it 'rejects an expiry in the past on create' do
      expect(build(:better_together_platform_management, expires_at: 1.hour.ago)).not_to be_valid
    end

    it 'does not let the endpoints change' do
      record = edge(operator, hosted)
      record.managed_platform = hosted
      expect(record).not_to be_valid
    end
  end

  describe 'cycles and depth' do
    it 'rejects a direct cycle' do
      a = operator
      b = operator
      edge(a, b)
      expect(build(:better_together_platform_management, operator_platform: b, managed_platform: a, transport: 'direct'))
        .not_to be_valid
    end

    it 'rejects a longer cycle' do
      a = operator
      b = operator
      c = operator
      edge(a, b)
      edge(b, c)
      cycle = build(:better_together_platform_management, operator_platform: c, managed_platform: a)
      expect(cycle).not_to be_valid
      expect(cycle.errors[:managed_platform_id]).to be_present
    end

    it 'allows a chain up to the depth limit and rejects one longer' do
      ops = Array.new(6) { operator }
      edge(ops[0], ops[1])
      edge(ops[1], ops[2])
      edge(ops[2], ops[3])
      edge(ops[3], ops[4])
      too_long = build(:better_together_platform_management, operator_platform: ops[4], managed_platform: ops[5])
      expect(too_long).not_to be_valid
      expect(too_long.errors[:base]).to be_present
    end

    it 'ignores revoked edges when checking the graph' do
      a = operator
      b = operator
      create(:better_together_platform_management, :revoked, operator_platform: a, managed_platform: b)
      expect(build(:better_together_platform_management, operator_platform: b, managed_platform: a)).to be_valid
    end
  end

  describe 'delegation chain (BTS host, client host, hosted platform)' do
    let(:bts) { operator }
    let(:client_host) { operator }
    let(:site) { hosted }
    let!(:bts_over_host) { edge(bts, client_host, granted_scopes: %w[read support billing]) }
    let!(:host_over_site) { edge(client_host, site, granted_scopes: %w[read support manage_content]) }

    it 'accepts a narrower derived edge' do
      expect(build_derived).to be_valid
    end

    it 'accepts the equal scope set' do
      expect(build_derived(granted_scopes: %w[read support manage_content])).to be_valid
    end

    it 'rejects a derived edge granting more than the parent holds' do
      record = build_derived(granted_scopes: %w[read billing])
      expect(record).not_to be_valid
      expect(record.errors[:granted_scopes]).to be_present
    end

    it 'rejects a parent edge on a different managed platform' do
      record = build_derived(managed_platform: hosted, delegated_from: host_over_site)
      expect(record).not_to be_valid
    end

    it 'requires the operator to hold an edge over the delegating platform' do
      record = build_derived(operator_platform: operator)
      expect(record).not_to be_valid
      expect(record.errors[:delegated_from]).to be_present
    end

    it 'computes effective scopes through the chain' do
      record = build_derived(granted_scopes: %w[read support]).tap(&:save!)
      expect(record.effective_scopes).to contain_exactly('read', 'support')
      expect(described_class.effective_scopes_for(bts, site)).to contain_exactly('read', 'support')
    end

    it 'shrinks derived scopes when the parent is narrowed' do
      record = build_derived(granted_scopes: %w[read support]).tap(&:save!)
      host_over_site.narrow!(%w[read], by: steward)
      expect(record.reload.effective_scopes).to eq(%w[read])
    end

    it 'makes derived edges ineffective when the parent is revoked, suspended or expired' do
      record = build_derived.tap(&:save!)
      host_over_site.suspend!(by: steward)
      expect(record.reload).not_to be_effective
      host_over_site.resume!(by: steward)
      expect(record.reload).to be_effective
      host_over_site.revoke!(by: steward)
      expect(record.reload.effective_scopes).to eq([])
    end

    it 'makes derived edges ineffective when the upstream edge over the delegator lapses' do
      record = build_derived.tap(&:save!)
      bts_over_host.revoke!(by: steward)
      expect(record.reload).not_to be_effective
    end

    it 'makes derived edges ineffective when the parent expires' do
      record = build_derived.tap(&:save!)
      host_over_site.update_columns(expires_at: 1.minute.ago) # rubocop:disable Rails/SkipsModelValidations
      expect(record.reload).not_to be_effective
    end

    it 'looks up operators and managed platforms through effective edges only' do
      record = build_derived.tap(&:save!)
      expect(described_class.operators_of(site)).to contain_exactly(client_host, bts)
      expect(described_class.managed_by(bts)).to contain_exactly(client_host, site)
      record.suspend!(by: steward)
      expect(described_class.operators_of(site)).to contain_exactly(client_host)
    end
  end

  describe 'lifecycle' do
    let(:record) { create(:better_together_platform_management, granted_scopes: %w[read support billing]) }

    before do
      allow(BetterTogether::TenancyAudit).to receive(:record).and_call_original
    end

    it 'accepts, optionally narrowing, and records the consent' do
      record.accept!(by: steward, scopes: %w[read])
      expect(record).to be_active
      expect(record.granted_scopes).to eq(%w[read])
      expect(record.accepted_by).to eq(steward)
      expect(record.accepted_at).to be_present
      expect(BetterTogether::TenancyAudit).to have_received(:record).with('platform_management.accepted', anything)
    end

    it 'refuses to widen scopes on accept or narrow' do
      expect { record.accept!(by: steward, scopes: %w[read manage_settings]) }.to raise_error(ArgumentError)
      record.accept!(by: steward)
      expect { record.narrow!(%w[read manage_settings], by: steward) }.to raise_error(ArgumentError)
    end

    it 'suspends, resumes and revokes, and revoked is terminal' do
      record.accept!(by: steward)
      record.suspend!(by: steward)
      expect(record).to be_suspended
      record.resume!(by: steward)
      record.revoke!(by: steward)
      expect(record).to be_revoked
      expect(record.status_changed_by).to eq(steward)
      expect { record.resume!(by: steward) }.to raise_error(ArgumentError)
      expect { record.narrow!(%w[read], by: steward) }.to raise_error(ArgumentError)
    end

    it 'blocks reopening a revoked edge' do
      record.revoke!(by: steward)
      record.status = 'active'
      expect(record).not_to be_valid
    end

    it 'emits an audit event when requested' do
      allow(BetterTogether::TenancyAudit).to receive(:record)
      create(:better_together_platform_management)
      expect(BetterTogether::TenancyAudit).to have_received(:record).with('platform_management.requested', anything)
    end

    it 'treats a requested edge as not effective' do
      expect(record).not_to be_effective
    end
  end

  describe '.authorizes?' do
    let(:op) { operator }
    let(:site) { hosted }
    let(:person) { create(:better_together_person) }

    before do
      create(:better_together_person_platform_membership, member: person, joinable: op, status: 'active')
    end

    it 'is false without an edge' do
      expect(described_class.authorizes?(person, site)).to be false
    end

    it 'is true through an effective edge, honouring scope' do
      edge(op, site, granted_scopes: %w[read])
      expect(described_class.authorizes?(person, site)).to be true
      expect(described_class.authorizes?(person, site, scope: 'read')).to be true
      expect(described_class.authorizes?(person, site, scope: 'billing')).to be false
    end

    it 'accepts a user' do
      user = create(:better_together_user, person:)
      edge(op, site)
      expect(described_class.authorizes?(user, site)).to be true
    end

    it 'is false for suspended, requested or expired edges and for outsiders' do
      record = edge(op, site)
      expect(described_class.authorizes?(create(:better_together_person), site)).to be false
      record.suspend!(by: person)
      expect(described_class.authorizes?(person, site)).to be false
      record.resume!(by: person)
      record.update_columns(expires_at: 1.minute.ago) # rubocop:disable Rails/SkipsModelValidations
      expect(described_class.authorizes?(person, site)).to be false
    end

    it 'is false for a pending membership' do
      other = create(:better_together_person)
      create(:better_together_person_platform_membership, member: other, joinable: op, status: 'pending')
      edge(op, site)
      expect(described_class.authorizes?(other, site)).to be false
    end
  end
end
