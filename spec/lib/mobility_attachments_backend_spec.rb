# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Mobility Attachments Backend (prototype)', type: :model do
  before do
    # Create a temporary table for the dummy model
    ActiveRecord::Base.connection.create_table(:mobility_attachment_dummies, id: :uuid) do |t|
      t.string :dummy
    end

    dummy = Class.new(ActiveRecord::Base) do
      self.table_name = 'mobility_attachment_dummies'
      extend Mobility

      begin
        translates_attached :hero_image
      rescue StandardError => e
        # noop if shim not available in this bootstrap
        Rails.logger.debug "translates_attached unavailable: #{e.message}"
      end
    end
    stub_const('MobilityAttachmentDummy', dummy)
  end

  after do
    drop_table :mobility_attachment_dummies
  rescue StandardError
    nil
  end

  it 'defines localized accessors for configured attribute' do
    locales = begin
      Mobility.available_locales
    rescue StandardError
      I18n.available_locales
    end
    locales.each do |locale|
      accessor = Mobility.normalize_locale_accessor('hero_image', locale)
      expect(MobilityAttachmentDummy).to be_method_defined(accessor)
      expect(MobilityAttachmentDummy).to be_method_defined("#{accessor}=")
      expect(MobilityAttachmentDummy).to be_method_defined("#{accessor}?")
      expect(MobilityAttachmentDummy).to be_method_defined("#{accessor}_url")
    end
  end
end

# rubocop:enable RSpec/ExampleLength, RSpec/MultipleExpectations
