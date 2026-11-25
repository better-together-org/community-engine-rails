# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ContactDetailPolicy, type: :policy do
  let(:host) { BetterTogether::Platform.find_by!(host: true) }
  let(:owner) { create(:better_together_user, :confirmed) }
  let(:stranger) { create(:better_together_user, :confirmed) }
  let(:manager) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:steward) { create(:better_together_user, :confirmed, :platform_steward) }

  before { configure_host_platform }

  def new_person_with_privacy(user, privacy)
    user.person.update_columns(privacy:) # rubocop:disable Rails/SkipsModelValidations
    user.person.reload.contact_detail
  end

  def visible_to(user, model = BetterTogether::ContactDetail)
    described_class::Scope.new(user, model).resolve
  end

  def detail_for(user, privacy: 'public')
    new_person_with_privacy(user, privacy)
  end

  describe 'create? update? destroy? on a person contact detail' do
    let(:detail) { detail_for(owner) }

    %i[create? update? destroy?].each do |action|
      it "allows the person themself for #{action}" do
        expect(described_class.new(owner, detail).public_send(action)).to be true
      end

      it "denies anonymous for #{action}" do
        expect(described_class.new(nil, detail).public_send(action)).to be false
      end

      it "denies another signed-in user for #{action}", :aggregate_failures do
        expect(described_class.new(stranger, detail).public_send(action)).to be false
      end

      it "gives platform managers and stewards no standing right for #{action}", :aggregate_failures do
        expect(described_class.new(manager, detail).public_send(action)).to be false
        expect(described_class.new(steward, detail).public_send(action)).to be false
      end
    end

    it 'denies creating a detail that has no contactable' do
      expect(described_class.new(owner, BetterTogether::ContactDetail.new).create?).to be false
    end

    it 'denies a class-level check' do
      expect(described_class.new(owner, BetterTogether::ContactDetail).create?).to be false
    end
  end

  describe 'an unclaimed person (no confirmed linked user)' do
    let(:person) { create(:better_together_person, privacy: 'public') }
    let(:detail) { person.contact_detail.reload }

    it 'is unclaimed' do
      expect(person).not_to be_claimed
    end

    %i[create? update? destroy?].each do |action|
      it "lets whoever may update the person (managers, stewards) use #{action}", :aggregate_failures do
        expect(described_class.new(manager, detail).public_send(action)).to be true
        expect(described_class.new(steward, detail).public_send(action)).to be true
      end

      it "denies anonymous and ordinary users for #{action}", :aggregate_failures do
        expect(described_class.new(nil, detail).public_send(action)).to be false
        expect(described_class.new(stranger, detail).public_send(action)).to be false
      end
    end

    it 'treats a person whose user is unconfirmed as unclaimed', :aggregate_failures do
      unconfirmed = create(:better_together_user)
      unconfirmed.update_columns(confirmed_at: nil) # rubocop:disable Rails/SkipsModelValidations
      expect(unconfirmed.person.reload).not_to be_claimed
      expect(owner.person.reload).to be_claimed
    end

    it 'still hides private rows from managers (visibility follows the row settings)', :aggregate_failures do
      hidden = create(:email_address, contact_detail: detail, privacy: 'private', primary_flag: false)
      shown = create(:email_address, contact_detail: detail.reload, privacy: 'public', primary_flag: false)
      rows = visible_to(manager, BetterTogether::EmailAddress)
      expect(rows).to include(shown)
      expect(rows).not_to include(hidden)
    end
  end

  describe 'create? update? destroy? on a community contact detail' do
    let(:community) { create(:better_together_community, creator: owner.person, privacy: 'private') }
    let(:detail) { community.contact_detail }

    %i[create? update? destroy?].each do |action|
      it "allows whoever may update the community for #{action}" do
        expect(described_class.new(owner, detail).public_send(action)).to be true
      end

      it "denies a user who may not update the community for #{action}", :aggregate_failures do
        expect(described_class.new(nil, detail).public_send(action)).to be false
        expect(described_class.new(stranger, detail).public_send(action)).to be false
      end
    end
  end

  describe 'component records (inherit the contactable owner rule)' do
    let(:detail) { detail_for(owner) }
    let(:email) { create(:email_address, contact_detail: detail, privacy: 'public', primary_flag: false) }

    it 'lets the owner destroy their email address and refuses anyone else', :aggregate_failures do
      expect(BetterTogether::EmailAddressPolicy.new(owner, email).destroy?).to be true
      expect(BetterTogether::EmailAddressPolicy.new(stranger, email).destroy?).to be false
      expect(BetterTogether::EmailAddressPolicy.new(nil, email).destroy?).to be false
    end
  end

  describe 'Scope' do
    let(:public_detail) { detail_for(create(:better_together_user, :confirmed), privacy: 'public') }
    let(:private_detail) { detail_for(owner, privacy: 'private') }

    it 'inherits from PlatformRecordPolicy::Scope' do
      expect(described_class::Scope.superclass).to eq(BetterTogether::PlatformRecordPolicy::Scope)
    end

    it 'hides a private person contact detail from everyone but the person', :aggregate_failures do
      private_detail
      expect(visible_to(owner)).to include(private_detail)
      expect(visible_to(stranger)).not_to include(private_detail)
      expect(visible_to(manager)).not_to include(private_detail)
      expect(visible_to(steward)).not_to include(private_detail)
      expect(visible_to(nil)).not_to include(private_detail)
    end

    it 'lists a public person contact detail to anonymous and signed-in users', :aggregate_failures do
      public_detail
      expect(visible_to(nil)).to include(public_detail)
      expect(visible_to(stranger)).to include(public_detail)
    end

    context 'with component rows that carry their own privacy' do
      let(:detail) { detail_for(owner, privacy: 'public') }
      let!(:shown) { create(:email_address, contact_detail: detail, privacy: 'public', primary_flag: false) }
      let!(:hidden) { create(:email_address, contact_detail: detail, privacy: 'private', primary_flag: false) }

      it 'shows only public rows to others and every row to the owner', :aggregate_failures do
        expect(visible_to(stranger, BetterTogether::EmailAddress)).to include(shown)
        expect(visible_to(stranger, BetterTogether::EmailAddress)).not_to include(hidden)
        expect(visible_to(manager, BetterTogether::EmailAddress)).not_to include(hidden)
        expect(visible_to(nil, BetterTogether::EmailAddress)).not_to include(hidden)
        expect(visible_to(owner, BetterTogether::EmailAddress)).to include(shown, hidden)
      end

      it 'hides rows of a private person even when the row itself is public', :aggregate_failures do
        owner.person.update_columns(privacy: 'private') # rubocop:disable Rails/SkipsModelValidations
        expect(visible_to(stranger, BetterTogether::EmailAddress)).not_to include(shown)
        expect(visible_to(owner, BetterTogether::EmailAddress)).to include(shown)
      end
    end
  end
end
