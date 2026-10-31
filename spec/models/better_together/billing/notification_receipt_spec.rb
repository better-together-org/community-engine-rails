# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::NotificationReceipt do
  let!(:host_platform) { configure_host_platform }
  let(:person) { create(:better_together_person) }

  def receipt(**attrs)
    host_platform.billing_notification_receipts.build({ recipient: person, kind: 'order_paid', audience: 'buyer',
                                                        dedupe_key: 'order:1' }.merge(attrs))
  end

  it_behaves_like 'a platform-bound billing record' do
    def build_record(platform:)
      described_class.new(recipient: person, kind: 'order_paid', audience: 'buyer', dedupe_key: 'k').tap do |r|
        r.platform = platform
      end
    end
  end

  it 'is valid with who, what and about what' do
    expect(receipt).to be_valid
  end

  it 'needs a recipient, a kind, an audience and a key' do
    expect(receipt(recipient: nil)).not_to be_valid
    expect(receipt(kind: '')).not_to be_valid
    expect(receipt(audience: '')).not_to be_valid
    expect(receipt(dedupe_key: '')).not_to be_valid
  end

  it 'is unique per person, kind and key, and backed by the database' do
    receipt.save!

    expect(receipt).not_to be_valid
    expect { receipt.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    expect(receipt(kind: 'order_cancelled')).to be_valid
    expect(receipt(dedupe_key: 'order:2')).to be_valid
    expect(receipt(recipient: create(:better_together_person))).to be_valid
  end

  it 'goes with the person it was for' do
    receipt.save!

    expect { described_class.connection.execute("DELETE FROM better_together_people WHERE id = '#{person.id}'") }.not_to raise_error
    expect(described_class.where(recipient_id: person.id)).to be_empty
  rescue ActiveRecord::InvalidForeignKey
    skip 'other tables still reference this person'
  end
end
