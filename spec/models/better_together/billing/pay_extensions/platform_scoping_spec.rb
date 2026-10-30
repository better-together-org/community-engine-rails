# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::PayExtensions::PlatformScoping do
  let(:platform_a) { create(:better_together_platform) }
  let(:platform_b) { create(:better_together_platform) }
  let(:owner) { create(:better_together_person) }

  def new_customer(platform:, owner: self.owner)
    Pay::Customer.new(owner:, platform:, processor: 'stripe', processor_id: "cus_#{SecureRandom.hex(6)}")
  end

  def new_subscription(customer, platform: nil)
    Pay::Subscription.new(customer:, platform:, name: 'default', processor_id: "sub_#{SecureRandom.hex(6)}",
                          processor_plan: 'price_1', status: 'active')
  end

  describe Pay::Customer do
    it_behaves_like 'a platform-bound billing record' do
      def build_record(platform:) = new_customer(platform:)
    end

    it 'cannot be re-pointed at another platform, as Pay set_payment_processor would do for a shared owner' do
      customer = new_customer(platform: platform_a).tap(&:save!)

      customer.platform = platform_b

      expect { customer.save! }.to(raise_error do |error|
        expect(error).to be_a(ActiveRecord::RecordInvalid).or be_a(ActiveRecord::ReadonlyAttributeError)
      end)
      expect(customer.reload.platform).to eq(platform_a)
    end

    it 'lets the same owner be a customer of two platforms' do
      new_customer(platform: platform_a).save!

      expect(new_customer(platform: platform_b)).to be_valid
    end

    it 'must be billed on the platform a platform-bound owner belongs to' do
      community = create(:better_together_community)
      bound_id = platform_a.id
      community.define_singleton_method(:billing_bound_platform_id) { bound_id }

      expect(new_customer(platform: platform_b, owner: community)).not_to be_valid
      expect(new_customer(platform: platform_a, owner: community)).to be_valid
    end

    it 'does not tie a person to one platform, even though a person has a home platform of their own' do
      expect(owner).to respond_to(:platform_id)
      expect(new_customer(platform: platform_a)).to be_valid
      expect(new_customer(platform: platform_b)).to be_valid
    end
  end

  describe Pay::Merchant do
    it_behaves_like 'a platform-bound billing record' do
      def build_record(platform:) = Pay::Merchant.new(owner:, platform:, processor: 'stripe')
    end
  end

  describe 'records that hang off a customer' do
    let!(:customer) { new_customer(platform: platform_a).tap(&:save!) }

    it 'inherit the customer platform instead of guessing one' do
      Current.platform = platform_b
      subscription = new_subscription(customer)

      expect(subscription).to be_valid
      expect(subscription.platform).to eq(platform_a)
    ensure
      Current.platform = nil
    end

    it 'are invalid on a different platform than their customer' do
      subscription = new_subscription(customer, platform: platform_b)

      expect(subscription).not_to be_valid
      expect(subscription.errors.details[:platform]).to include(a_hash_including(error: :platform_parent_mismatch))
    end

    it 'applies to charges and payment methods too, including a charge and its subscription' do
      subscription = new_subscription(customer).tap(&:save!)
      charge = Pay::Charge.new(customer:, subscription:, processor_id: 'ch_1', amount: 100)
      method = Pay::PaymentMethod.new(customer:, processor_id: 'pm_1')

      expect(charge).to be_valid
      expect(charge.platform).to eq(platform_a)
      expect(method).to be_valid
      expect(method.platform).to eq(platform_a)
      expect(Pay::Charge.new(customer:, subscription:, platform: platform_b, processor_id: 'ch_2', amount: 1)).not_to be_valid
    end
  end

  describe 'the database' do
    let!(:customer) { new_customer(platform: platform_a).tap(&:save!) }

    it 'refuses a subscription on another platform than its customer even when validations are skipped' do
      expect { new_subscription(customer, platform: platform_b).save!(validate: false) }
        .to raise_error(ActiveRecord::InvalidForeignKey)
    end

    it 'refuses a charge on another platform than its customer even when validations are skipped' do
      expect { Pay::Charge.new(customer:, platform: platform_b, processor_id: 'ch_1', amount: 1).save!(validate: false) }
        .to raise_error(ActiveRecord::InvalidForeignKey)
    end

    it 'refuses a charge moved to another platform than its subscription, even around the model' do
      subscription = new_subscription(customer).tap(&:save!)
      charge = Pay::Charge.new(customer:, subscription:, platform: platform_a, processor_id: 'ch_3', amount: 1)

      charge.save!
      # update_columns is stopped earlier by attr_readonly, so go to the database directly.
      expect do
        Pay::Charge.connection.execute(
          "UPDATE pay_charges SET platform_id = #{Pay::Charge.connection.quote(platform_b.id)} " \
          "WHERE id = #{Pay::Charge.connection.quote(charge.id)}"
        )
      end.to raise_error(ActiveRecord::InvalidForeignKey)
    end
  end
end
