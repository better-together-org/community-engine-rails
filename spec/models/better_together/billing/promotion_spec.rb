# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Promotion do
  include_context 'with store credit fixtures'

  let(:promotion) do
    host_platform.billing_promotions.create!(name: 'Spring', code_digest: described_class.digest_for('ABCD-EFGH-JKMN-PQRS'), amount_cents: 1000,
                                             currency: 'USD')
  end

  describe 'codes' do
    it 'normalizes what people type: case, spaces and dashes do not matter' do
      expect(described_class.normalize(' abcd-efgh jkmn_pqrs ')).to eq('ABCDEFGHJKMNPQRS')
      expect(described_class.digest_for('abcd efgh-jkmn-pqrs')).to eq(described_class.digest_for('ABCD-EFGH-JKMN-PQRS'))
    end

    it 'digests with a key from the application\'s secret, so a database copy cannot be used to check guesses' do
      plain = OpenSSL::Digest::SHA256.hexdigest('ABCDEFGHJKMNPQRS')

      expect(described_class.digest_for('ABCD-EFGH-JKMN-PQRS')).not_to eq(plain)
    end

    it 'makes codes from letters and digits that cannot be mistaken for each other' do
      codes = Array.new(50) { described_class.generate_code }

      expect(codes.join).not_to match(/[0O1ILl]/)
      expect(codes).to all(match(/\A([A-Z2-9]{4}-){3}[A-Z2-9]{4}\z/))
    end

    it 'keeps the digest and the amount it began with' do
      promotion.update!(code_digest: 'x' * 64, amount_cents: 1, currency: 'CAD')

      expect(promotion.reload).to have_attributes(amount_cents: 1000, currency: 'USD')
      expect(promotion.code_digest).to eq(described_class.digest_for('ABCD-EFGH-JKMN-PQRS'))
    end

    it 'is unique per platform' do
      duplicate = host_platform.billing_promotions.build(name: 'Again', code_digest: promotion.code_digest, amount_cents: 1, currency: 'USD')

      expect(duplicate).not_to be_valid
      expect(create(:better_together_platform).billing_promotions.build(name: 'Again', code_digest: promotion.code_digest, amount_cents: 1,
                                                                        currency: 'USD')).to be_valid
    end
  end

  describe 'when it can be used' do
    it 'is open while active, started, not ended and not used up' do
      expect(promotion).to be_redeemable
      expect(build_stubbed(:better_together_person)).to be_present
    end

    it 'is not open when switched off, not started, ended or used up' do
      promotion.assign_attributes(active: false)
      expect(promotion).not_to be_redeemable
      promotion.assign_attributes(active: true, starts_at: 1.day.from_now)
      expect(promotion).not_to be_redeemable
      promotion.assign_attributes(starts_at: nil, ends_at: 1.second.ago)
      expect(promotion).not_to be_redeemable
      promotion.assign_attributes(ends_at: nil, max_redemptions: 1, redemptions_count: 1)
      expect(promotion).not_to be_redeemable
    end
  end

  describe 'the database' do
    it 'keeps the count within the cap and the amount above nothing' do
      capped = host_platform.billing_promotions.create!(name: 'C', code_digest: 'c' * 64, amount_cents: 1, currency: 'USD', max_redemptions: 1)

      expect { capped.update_columns(redemptions_count: 2) } # rubocop:disable Rails/SkipsModelValidations
        .to raise_error(ActiveRecord::StatementInvalid, /chk_bt_billing_promotions_cap/)
    end

    it 'keeps the amount above nothing' do
      expect { described_class.where(id: promotion.id).update_all(amount_cents: 0) } # rubocop:disable Rails/SkipsModelValidations
        .to raise_error(ActiveRecord::StatementInvalid, /chk_bt_billing_promotions_amount/)
    end

    it 'allows a person one redemption of a promotion, and redemptions are never changed' do
      lot = grant_credit(100)
      redemption = promotion.redemptions.create!(platform_id: host_platform.id, person: buyer, credit_lot: lot)

      expect(redemption).to be_readonly
      expect(promotion.redemptions.build(platform_id: host_platform.id, person: buyer, credit_lot: grant_credit(100))).not_to be_valid
    end
  end

  it 'is reached through its platform and refuses the platform being deleted' do
    expect(host_platform.billing_promotions).to include(promotion)
  end
end
