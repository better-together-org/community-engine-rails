# frozen_string_literal: true

# rubocop:disable RSpec/ExampleLength, RSpec/MultipleExpectations, RSpec/DescribeClass

require 'rails_helper'

RSpec.describe 'Translatable Attachments writer' do
  before do
    ActiveRecord::Base.connection.create_table(:translatable_attachment_writer_dummies, id: :uuid) do |t|
      t.string :dummy
    end

    klass = Class.new(ActiveRecord::Base) do
      self.table_name = 'translatable_attachment_writer_dummies'
      extend Mobility::DSL::Attachments

      translates_attached :hero_image
    end
    stub_const('TranslatableAttachmentWriterDummy', klass)
  end

  after do
    drop_table :translatable_attachment_writer_dummies
  rescue StandardError
    nil
  end

  let(:model_class) { TranslatableAttachmentWriterDummy }

  it 'attaches an ActiveStorage::Blob via the writer' do
    model = model_class.create!(dummy: 'w')
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new('blob data'), filename: 'blob.txt',
                                                  content_type: 'text/plain')

    expect { model.hero_image_en = blob }.not_to raise_error

    att = model.hero_image_en
    expect(att).to be_present
    expect(att.blob).to eq(blob)
    expect(model).to be_hero_image
  end

  it 'uploads IO-like objects via the writer' do
    model = model_class.create!(dummy: 'io')
    io = StringIO.new('io data')

    expect { model.hero_image_en = io }.not_to raise_error

    att = model.hero_image_en
    expect(att).to be_present
    expect(att.blob).to be_present
    expect(att.blob.byte_size).to be > 0
  end

  it 'purges and removes the attachment when assigning nil' do
    model = model_class.create!(dummy: 'nil')
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new('to purge'), filename: 'purge.txt')
    model.hero_image_en = blob

    expect(model).to be_hero_image

    expect { model.hero_image_en = nil }.not_to raise_error

    expect(model.hero_image_en).to be_nil
    expect(model).not_to be_hero_image
  end

  it 'replaces existing attachment and leaves old blob unattached (can be purged)' do
    model = model_class.create!(dummy: 'replace')
    old_blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new('old'), filename: 'old.txt')
    model.hero_image_en = old_blob

    expect(model.hero_image_en.blob).to eq(old_blob)

    new_blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new('new'), filename: 'new.txt')
    model.hero_image_en = new_blob

    expect(model.hero_image_en.blob).to eq(new_blob)
    # old blob should no longer have attachments
    expect(old_blob.attachments.count).to eq(0)

    # if desired, old_blob can be purged
    old_blob.purge
    expect(ActiveStorage::Blob.find_by(id: old_blob.id)).to be_nil
  end

  it 'accepts named variants on the model reflection without raising' do
    # inject a named variant object on the reflection so ActiveStorage callbacks can inspect it
    ref = model_class.attachment_reflections['hero_image']
    named_variant = Struct.new(:preprocessed?, :transformations).new(false, { resize_to_limit: [50, 50] })
    ref.named_variants['thumb'] = named_variant

    model = model_class.create!(dummy: 'variant')
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new('img'), filename: 'img.jpg',
                                                  content_type: 'image/jpeg')

    expect { model.hero_image_en = blob }.not_to raise_error
    expect(model.hero_image_en).to be_present
  end

  it 'uses the storage service upload when creating blobs (stubbed service)' do
    model = model_class.create!(dummy: 'service')
    io = StringIO.new('service data')

    # Spy on the higher-level API so we can assert it was used without stubbing behavior
    allow(ActiveStorage::Blob).to receive(:create_and_upload!).and_call_original
    expect { model.hero_image_en = io }.not_to raise_error
    expect(ActiveStorage::Blob).to have_received(:create_and_upload!).at_least(:once)
  end
end

# rubocop:enable RSpec/ExampleLength, RSpec/MultipleExpectations, RSpec/DescribeClass
