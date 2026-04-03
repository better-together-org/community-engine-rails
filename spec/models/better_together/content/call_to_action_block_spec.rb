# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Content
    RSpec.describe CallToActionBlock do
      subject(:block) { described_class.new(layout: 'centered') }

      it 'is a subclass of Content::Block' do
        expect(described_class.superclass).to eq(BetterTogether::Content::Block)
      end

      it 'is not content_addable pending deferred rollout review' do
        expect(described_class.content_addable?).to be false
      end

      describe 'defaults' do
        it 'defaults layout to centered' do
          expect(described_class.new.layout).to eq('centered')
        end

        it 'defaults heading to empty string' do
          expect(described_class.new.heading).to eq('')
        end
      end

      describe 'validations' do
        it 'validates layout inclusion' do
          block.layout = 'invalid'
          block.valid?
          expect(block.errors[:layout]).not_to be_empty
        end

        it 'accepts all valid layouts' do
          CallToActionBlock::LAYOUTS.each do |l|
            block.layout = l
            block.valid?
            expect(block.errors[:layout]).to be_empty
          end
        end
      end

      describe '#extra_permitted_attributes' do
        it 'includes all CTA attributes' do
          attrs = described_class.extra_permitted_attributes
          expect(attrs).to include(:heading, :primary_button_label, :primary_button_url,
                                   :secondary_button_label, :secondary_button_url, :layout)
        end
      end
    end
  end
end
