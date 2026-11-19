# frozen_string_literal: true

# Sensitive billing attributes are encrypted at rest. The including example group
# provides:
#   encrypted_fields  - { attribute_name => plaintext value to store }
#   saved_record      - a persisted record holding those values
#
# The test environment sets `support_unencrypted_data = true` globally, which would
# hide a forgotten `encrypts`; these examples therefore look at the stored
# ciphertext rather than only at round-tripping.
RSpec.shared_examples 'encrypts sensitive billing fields' do
  it 'stores ciphertext, not the plaintext' do
    encrypted_fields.each do |name, plaintext|
      expect(saved_record.encrypted_attribute?(name)).to be(true), "#{name} is not stored encrypted"
      expect(saved_record.ciphertext_for(name)).not_to include(plaintext.to_s)
    end
  end

  it 'writes the Active Record Encryption envelope to the column' do
    encrypted_fields.each_key do |name|
      raw = described_class.connection.select_value(
        "SELECT #{name} FROM #{described_class.table_name} WHERE id = #{described_class.connection.quote(saved_record.id)}"
      )

      expect(JSON.parse(raw)).to include('p', 'h')
    end
  end

  it 'reads the values back' do
    reloaded = described_class.find(saved_record.id)

    encrypted_fields.each { |name, plaintext| expect(reloaded.public_send(name)).to eq(plaintext) }
  end

  it 'refuses a plaintext value written around the model, even though the test environment tolerates unencrypted data' do
    name = encrypted_fields.keys.first
    described_class.connection.execute(
      "UPDATE #{described_class.table_name} SET #{name} = '{\"plain\":true}' " \
      "WHERE id = #{described_class.connection.quote(saved_record.id)}"
    )

    expect { described_class.find(saved_record.id).public_send(name) }.to raise_error(ActiveRecord::Encryption::Errors::Decryption)
  end

  it 'declares text columns with no default and no limit, as the encryption guide requires' do
    expect { described_class.verify_encrypted_billing_columns! }.not_to raise_error
  end
end
