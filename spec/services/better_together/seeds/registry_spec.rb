# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Seeds::Registry do
  after { described_class.reset! }

  describe 'default registrations' do
    it 'registers the record types the foray packet needs' do
      expect(described_class.types.map(&:name)).to include(
        :page, :content_block, :page_block, :navigation_area, :navigation_item, :upload, :event,
        :social_media_account, :contact_detail
      )
    end

    it 'maps every type to a loadable model with a natural key it can query' do
      described_class.types.each do |definition|
        expect(definition.model).to be < ActiveRecord::Base
        next if definition.by_refs.any?

        expect(definition.model.column_names).to include(definition.natural_key_columns.first.to_s)
      end
    end

    it 'declares only attributes the model can write' do
      described_class.types.each do |definition|
        records = definition.sti_allowed ? definition.sti_allowed.call.map { |n| n.constantize.new } : [definition.model.new]
        (definition.writable_attributes + definition.translated_attributes).each do |attribute|
          expect(records).to(be_any { |r| r.respond_to?("#{attribute}=") }, "#{definition.name}.#{attribute}= is not writable")
        end
      end
    end

    it 'declares attachments that exist on the model' do
      described_class.types.each do |definition|
        definition.attachments.each_key do |attachment|
          expect(definition.model.new).to respond_to(attachment), "#{definition.name} has no #{attachment}"
        end
      end
    end

    it 'names references after real associations of the model' do
      described_class.types.each do |definition|
        definition.references.each_key do |slot|
          expect(definition.model.reflect_on_association(slot)).to be_present, "#{definition.name} has no association #{slot}"
        end
      end
    end

    it 'points every reference at a registered type' do
      described_class.types.each do |definition|
        definition.references.each_value do |ref|
          ref.types.each { |type| expect(described_class.registered?(type)).to be(true), "#{definition.name} -> #{type}" }
        end
      end
    end

    it 'orders types after the types they reference' do
      order = described_class.ordered.map(&:name)

      expect(order.index(:navigation_area)).to be < order.index(:navigation_item)
      expect(order.index(:page)).to be < order.index(:page_block)
      expect(order.index(:contact_detail)).to be < order.index(:social_media_account)
    end

    it 'lets the content block choose among its STI subclasses' do
      definition = described_class.fetch(:content_block)

      expect(definition.sti_allowed.call).to include('BetterTogether::Content::RichText')
    end
  end

  describe '.register' do
    it 'accepts host-app types without an importer class' do
      described_class.register(:district) do
        model 'BetterTogether::Community'
        natural_key :identifier
        attributes :privacy
      end

      expect(described_class.fetch(:district).model).to eq(BetterTogether::Community)
    end

    it 'rejects a within key that is not a reference' do
      expect do
        described_class.register(:broken) do
          model 'BetterTogether::Community'
          natural_key :name, within: :nothing
        end
      end.to raise_error(ArgumentError, /not a reference/)
    end

    it 'rejects a definition without a model' do
      expect { described_class.register(:modelless) { attributes :a } }.to raise_error(ArgumentError, /needs a model/)
    end

    it 'detects dependency cycles' do
      described_class.register(:a) do
        model 'BetterTogether::Page'
        reference(:b, to: :b)
      end
      described_class.register(:b) do
        model 'BetterTogether::Page'
        reference(:a, to: :a)
      end

      expect { described_class.ordered }.to raise_error(described_class::DependencyCycle, /a -> b -> a/)
    end

    it 'raises for unknown types' do
      expect { described_class.fetch(:nope) }.to raise_error(described_class::UnknownType)
    end

    it 'freezes registered definitions' do
      expect(described_class.fetch(:page)).to be_frozen
    end
  end

  describe 'TypeDefinition#find' do
    let(:platform) { create(:better_together_platform) }

    it 'finds a record by natural key inside the target platform only' do
      page = create(:better_together_page, platform:, identifier: 'about', privacy: 'private')
      other = create(:better_together_platform)
      create(:better_together_page, platform: other, identifier: 'about', privacy: 'private')

      expect(described_class.fetch(:page).find(platform:, key: 'about')).to eq(page)
    end

    it 'returns nil when the key is absent' do
      expect(described_class.fetch(:page).find(platform:, key: 'missing')).to be_nil
    end
  end
end
