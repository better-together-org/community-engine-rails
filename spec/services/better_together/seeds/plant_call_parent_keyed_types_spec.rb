# frozen_string_literal: true

require 'rails_helper'

# Types keyed `within:` a parent (contact_detail within its contactable, social_media_account within
# its contact_detail) are located through the parent records their own refs name.
RSpec.describe BetterTogether::Seeds::Plant, '.call parent keyed types' do
  let!(:platform) { create(:better_together_platform) }
  let(:dir) { Dir.mktmpdir('seed-packet') }
  let(:platform_ref) { { 'type' => 'platform', 'key' => platform.identifier, 'scope' => 'platform' } }
  let(:details) { [{ 'key' => 'Main', 'refs' => { 'contactable' => platform_ref } }] }
  let(:accounts) do
    [{ 'key' => 'Facebook', 'attributes' => { 'platform_name' => 'Facebook', 'handle' => 'foray', 'url' => 'https://facebook.com/foray' },
       'refs' => { 'contact_detail' => 'contact_detail:Main' } }]
  end
  let(:records) { { contact_detail: details, social_media_account: accounts } }

  before { build_packet(dir, records:) }

  after { FileUtils.remove_entry(dir) }

  def plant(apply: true)
    described_class.call(path: dir, platform:, apply:)
  end

  def record_counts
    [BetterTogether::ContactDetail.count, BetterTogether::SocialMediaAccount.count]
  end

  def accounts_for(contactable)
    BetterTogether::SocialMediaAccount.joins(:contact_detail).where(contact_details_query(contactable))
  end

  def contact_details_query(contactable)
    { better_together_contact_details: { contactable_type: contactable.class.base_class.name, contactable_id: contactable.id } }
  end

  it 'plans a contact detail and a social account that references it without raising' do
    report = plant(apply: false)

    expect(report).to include(dry_run: true, created: 2, errors: [])
    expect(BetterTogether::ContactDetail.where(contactable: platform)).to be_empty
  end

  it 'plants both and hangs the account off the contact detail of the declared contactable' do
    report = plant

    expect(report).to include(created: 2, errors: [])
    detail = BetterTogether::ContactDetail.find_by(contactable: platform, name: 'Main')
    expect(detail.social_media_accounts.pluck(:platform_name)).to eq(['Facebook'])
  end

  it 'reports unchanged on an identical rerun and creates nothing new' do
    plant

    rerun = nil
    expect { rerun = plant }.not_to(change { record_counts })
    expect(rerun).to include(created: 0, unchanged: 2, errors: [])
  end

  it 'plans the rerun of a dry run after a real plant as unchanged' do
    plant

    expect(plant(apply: false)).to include(created: 0, unchanged: 2, errors: [])
  end

  context 'when another contactable already has a contact detail with the same name' do
    before { BetterTogether::ContactDetail.create!(contactable: community, name: 'Main') }

    let(:community) { create(:better_together_community, platform:) }

    it 'keeps the account under the declared contactable, on plant and on rerun' do
      expect(plant).to include(created: 2, errors: [])
      expect(accounts_for(platform).pluck(:handle)).to eq(['foray'])
      expect(accounts_for(community)).to be_empty
      expect(plant).to include(created: 0, unchanged: 2, errors: [])
    end
  end

  context 'when the account hangs off a contact detail of a community' do
    let(:community) { create(:better_together_community, platform:) }
    let(:platform_ref) { { 'type' => 'community', 'key' => community.identifier, 'scope' => 'platform' } }

    it 'plants and reruns through the community contactable' do
      report = plant

      expect(report).to include(created: 2, errors: [])
      expect(accounts_for(community).pluck(:handle)).to eq(['foray'])
      expect(plant).to include(created: 0, unchanged: 2, errors: [])
    end
  end

  context 'when the contact detail names no contactable' do
    let(:details) { [{ 'key' => 'Main' }] }

    it 'fails the plan with a packet error instead of raising KeyError' do
      report = plant(apply: false)

      expect(report[:errors]).to include(include(record: 'contact_detail:Main', field: '/refs/contactable'))
      expect(report[:errors].join).not_to include('key not found')
    end
  end

  context 'when the contact detail points at a contactable that does not exist' do
    let(:platform_ref) { { 'type' => 'platform', 'key' => 'no-such-platform', 'scope' => 'platform' } }

    it 'fails with a not-found packet error and writes nothing' do
      report = nil
      expect { report = plant }.not_to(change { record_counts })
      expect(report[:errors]).to include(include(record: 'contact_detail:Main', field: '/refs/contactable'))
    end
  end

  context 'when the account references a contact detail that is not in the packet' do
    let(:records) { { social_media_account: accounts } }

    it 'fails with a clear packet error' do
      report = plant(apply: false)

      expect(report[:errors]).to include(include(record: 'social_media_account:Facebook', field: '/refs/contact_detail',
                                                 message: include('was not found in the packet or on the platform')))
    end
  end
end
