# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/content_security/item',
          class: 'BetterTogether::ContentSecurity::Item',
          aliases: %i[content_security_item] do
    transient do
      upload { create(:better_together_upload) }
    end

    association :attachable, factory: :better_together_upload
    attachment_name { 'file' }
    source_surface { 'uploads' }
    lifecycle_state { 'pending_scan' }
    aggregate_verdict { 'pending_scan' }

    before(:create) do |item, _evaluator|
      unless item.blob.present?
        blob = ActiveStorage::Blob.create_and_upload!(
          io: StringIO.new('test file content'),
          filename: "test-#{SecureRandom.hex(4)}.txt",
          content_type: 'text/plain'
        )
        item.blob = blob
      end
    end
  end
end
