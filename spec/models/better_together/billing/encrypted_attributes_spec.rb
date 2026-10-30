# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::EncryptedAttributes do
  let(:connection) { ActiveRecord::Base.connection }
  let(:table) { "tmp_encrypted_#{SecureRandom.hex(4)}" }

  def model_for(table_name, &)
    Class.new(ActiveRecord::Base) do
      self.table_name = table_name
      include BetterTogether::Billing::EncryptedAttributes

      def self.name = 'TmpEncryptedBillingModel'
      class_eval(&) if block_given?
    end
  end

  after { connection.drop_table(table, if_exists: true) }

  it 'declares the attribute encrypted, non-deterministic, with no tolerance for plaintext' do
    connection.create_table(table) { |t| t.text :secret }
    model = model_for(table) { encrypts_billing_attribute :secret }

    record = model.create!(secret: 'hunter2')

    expect(record.encrypted_attribute?(:secret)).to be(true)
    expect(record.ciphertext_for(:secret)).not_to include('hunter2')
    expect(model.encrypted_billing_attributes).to eq([:secret])
    expect(model.type_for_attribute(:secret).scheme.support_unencrypted_data?).to be(false)
    expect(model.type_for_attribute(:secret).scheme).not_to be_deterministic
  end

  it 'declares the JSON type before encrypting, so a Hash round-trips' do
    connection.create_table(table) { |t| t.text :payload }
    model = model_for(table) { encrypts_billing_attribute :payload, json: true, default: -> { {} } }

    expect(model.new.payload).to eq({})

    record = model.create!(payload: { 'id' => 'evt_1', 'nested' => { 'n' => 1 } })

    expect(model.find(record.id).payload).to eq({ 'id' => 'evt_1', 'nested' => { 'n' => 1 } })
    expect(record.ciphertext_for(:payload)).not_to include('evt_1')
  end

  describe 'column checks, run when the schema loads rather than at class-load time' do
    it 'rejects a column with a database default, which Rails would return undecrypted' do
      connection.create_table(table) { |t| t.text :secret, default: 'x' }

      expect { model_for(table) { encrypts_billing_attribute :secret }.columns_hash }
        .to raise_error(described_class::ColumnError, /database default/)
    end

    it 'rejects a column with a limit, which adds a plaintext length validation' do
      connection.create_table(table) { |t| t.string :secret, limit: 40 }

      expect { model_for(table) { encrypts_billing_attribute :secret }.columns_hash }
        .to raise_error(described_class::ColumnError, /limit of 40/)
    end

    it 'rejects a non-text column, such as jsonb, which cannot hold ciphertext' do
      connection.create_table(table) { |t| t.jsonb :secret }

      expect { model_for(table) { encrypts_billing_attribute :secret, json: true }.columns_hash }
        .to raise_error(described_class::ColumnError, /not text/)
    end

    it 'does not touch the database while the class is being defined' do
      expect { model_for('a_table_that_does_not_exist') { encrypts_billing_attribute :secret } }.not_to raise_error
    end
  end
end
