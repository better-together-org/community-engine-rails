# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::SignedVerifierRotation do
  let(:secret) { 'a' * 64 }
  let(:record) { create(:better_together_person) }

  def verifier_for(digest)
    key = ActiveSupport::KeyGenerator.new(secret, iterations: 1000, hash_digest_class: digest).generate_key('signed_global_ids')
    GlobalID::Verifier.new(key)
  end

  def sgid_signed_with(digest)
    SignedGlobalID.create(record, for: 'attachable', expires_in: nil, verifier: verifier_for(digest)).to_s
  end

  it 'verifies ids signed with the other key digest once rotated' do
    sgid = sgid_signed_with(OpenSSL::Digest::SHA256)
    primary = verifier_for(OpenSSL::Digest::SHA1)

    expect(SignedGlobalID.parse(sgid, for: 'attachable', verifier: primary)).to be_nil

    described_class.rotate(primary, salt: 'signed_global_ids', secret_key_base: secret)

    expect(SignedGlobalID.parse(sgid, for: 'attachable', verifier: primary)&.model_id).to eq(record.id)
  end

  it 'still verifies ids signed with the primary key' do
    primary = verifier_for(OpenSSL::Digest::SHA1)
    sgid = SignedGlobalID.create(record, for: 'attachable', expires_in: nil, verifier: primary).to_s

    described_class.rotate(primary, salt: 'signed_global_ids', secret_key_base: secret)

    expect(SignedGlobalID.parse(sgid, for: 'attachable', verifier: primary)&.model_id).to eq(record.id)
  end

  it 'does nothing without a secret' do
    expect(described_class.rotate(verifier_for(OpenSSL::Digest::SHA1), salt: 'x', secret_key_base: nil)).to be_nil
  end

  describe '.install!' do
    it 'rotates a verifier that GlobalID assigns after the install ran' do
      original = SignedGlobalID.verifier
      app = instance_double(Rails::Application, secret_key_base: secret)
      described_class.install!(app)
      late = verifier_for(OpenSSL::Digest::SHA1)
      sgid = sgid_signed_with(OpenSSL::Digest::SHA256)

      SignedGlobalID.verifier = late

      expect(SignedGlobalID.parse(sgid, for: 'attachable')&.model_id).to eq(record.id)
    ensure
      SignedGlobalID.verifier = original
    end
  end
end
