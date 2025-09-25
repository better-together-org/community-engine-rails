# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Translatable Attachments integration', type: :model do
  before do
    ActiveRecord::Base.connection.create_table(:translatable_attachment_integration_dummies, id: :uuid) do |t|
      t.string :name
    end

    klass = Class.new(ActiveRecord::Base) do
      self.table_name = 'translatable_attachment_integration_dummies'
      extend Mobility::DSL::Attachments

      translates_attached :hero_image
    end
    stub_const('TranslatableAttachmentIntegrationDummy', klass)
  end

  after do
    drop_table :translatable_attachment_integration_dummies
  rescue StandardError
    nil
  end

  let(:model_class) { TranslatableAttachmentIntegrationDummy }
  let(:insert_attachment_sql) do
    lambda do |instance, blob, locale = 'en'|
      sql = <<-SQL
        INSERT INTO active_storage_attachments (id, name, record_type, record_id, blob_id, created_at, locale)
        VALUES (gen_random_uuid(), 'hero_image', #{ActiveRecord::Base.connection.quote(instance.class.name)}, #{ActiveRecord::Base.connection.quote(instance.id.to_s)}, #{ActiveRecord::Base.connection.quote(blob.id.to_s)}, NOW(), #{ActiveRecord::Base.connection.quote(locale)})
      SQL
      ActiveRecord::Base.connection.execute(sql)
    end
  end

  it 'attaches a real blob and the getter returns the attachment' do
    instance = model_class.create!(name: 'test')
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new('PNGDATA'), filename: 'test.png',
                                                  content_type: 'image/png')
    insert_attachment_sql.call(instance, blob)

    instance.reload
    I18n.with_locale(:en) do
      expect(instance.hero_image).to be_present
    end
  end

  it 'returns a rails_blob_url for attached blob' do
    instance = model_class.create!(name: 'test2')
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new('PNGDATA2'), filename: 'test2.png',
                                                  content_type: 'image/png')
    insert_attachment_sql.call(instance, blob)

    instance.reload
    I18n.with_locale(:en) do
      expect(instance.hero_image_url(host: 'http://example.com')).to include('http://example.com')
    end
  end
end

# rubocop:enable RSpec/ExampleLength
