# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Community, :skip_host_setup do
  subject(:community) { build(:better_together_community) }

  describe 'Factory' do
    it 'has a valid factory' do
      expect(community).to be_valid
    end

    describe 'traits' do
      describe ':creator' do
        subject(:community_with_creator) { create(:better_together_community, :creator) }

        it 'creates a community with a creator' do
          expect(community_with_creator.creator).to be_present
          expect(community_with_creator.creator).to be_a(BetterTogether::Person)
        end
      end

      describe ':host' do
        subject(:host_community) do
          described_class.find_by(host: true) || create(:better_together_community, :host)
        end

        it 'creates a host community' do
          expect(host_community.host).to be true
        end
      end

      describe 'combined traits' do
        it 'works with :creator and :host' do
          community = described_class.find_by(host: true) || create(:better_together_community, :creator, :host)
          community.update!(creator: create(:better_together_person)) unless community.creator
          expect(community.creator).to be_present
          expect(community.host).to be true
        end
      end
    end
  end

  it_behaves_like 'a friendly slugged record'
  it_behaves_like 'has_id'

  describe 'ActiveRecord associations' do
    it { is_expected.to belong_to(:creator).class_name('::BetterTogether::Person').optional }
  end

  describe 'Attributes' do
    it { is_expected.to respond_to(:name) }
    it { is_expected.to respond_to(:description) }
    it { is_expected.to respond_to(:slug) }
    it { is_expected.to respond_to(:creator_id) }
    it { is_expected.to respond_to(:privacy) }
    it { is_expected.to respond_to(:host) }
  end

  describe 'Methods' do
    it { is_expected.to respond_to(:to_s) }
    it { is_expected.to respond_to(:set_as_host) }

    describe '#set_as_host' do
      context 'when there is no host community' do
        before do
          relation = instance_double(ActiveRecord::Relation, exists?: false)
          allow(described_class).to receive(:where).and_return(relation)
        end

        it 'sets the host attribute to true' do
          community.set_as_host
          expect(community.host).to be true
        end
      end

      context 'when a host community already exists' do
        before do
          relation = instance_double(ActiveRecord::Relation, exists?: true)
          allow(described_class).to receive(:where).and_return(relation)
        end

        it 'does not set the host attribute to true' do
          community.set_as_host
          expect(community.host).to be false
        end
      end
    end
  end

  describe '#to_s' do
    it 'returns the name as a string representation' do
      expect(community.to_s).to eq(community.name)
    end
  end

  describe '#optimized_cover_image' do
    let(:community) { described_class.allocate }
    let(:attachment_variant) { double('attachment_variant') } # rubocop:todo RSpec/VerifiedDoubles
    let(:cover_image) { double('cover_image', content_type: content_type) } # rubocop:todo RSpec/VerifiedDoubles

    before do
      community.define_singleton_method(:cover_image) { cover_image }
    end

    context 'when the cover image is a PNG' do
      let(:content_type) { 'image/png' }

      it 'returns the named variant without forcing request-time processing' do
        allow(cover_image).to receive(:variant).with(:optimized_png).and_return(attachment_variant)
        expect(attachment_variant).not_to receive(:processed)

        expect(community.optimized_cover_image).to eq(attachment_variant)
      end
    end
  end

  describe '#optimized_logo' do
    let(:community) { described_class.allocate }
    let(:attachment_variant) { double('attachment_variant') } # rubocop:todo RSpec/VerifiedDoubles
    let(:logo) { double('logo', content_type: content_type) } # rubocop:todo RSpec/VerifiedDoubles

    before do
      community.define_singleton_method(:logo) { logo }
    end

    context 'when the logo is a JPEG' do
      let(:content_type) { 'image/jpeg' }

      it 'returns the named variant without forcing request-time processing' do
        allow(logo).to receive(:variant).with(:optimized_jpeg).and_return(attachment_variant)
        expect(attachment_variant).not_to receive(:processed)

        expect(community.optimized_logo).to eq(attachment_variant)
      end
    end
  end

  describe 'callbacks' do
    describe '#create_default_calendar' do
      it 'creates uniquely slugged default calendars for different communities' do
        first = create(:better_together_community, name: 'Alpha Community')
        second = create(:better_together_community, name: 'Beta Community')
        first_calendar = first.calendars.find_by!(identifier: "default-#{first.identifier}")
        second_calendar = second.calendars.find_by!(identifier: "default-#{second.identifier}")

        expect(first_calendar.slug).to eq("default-#{first.identifier}")
        expect(second_calendar.slug).to eq("default-#{second.identifier}")
        expect(first_calendar.slug).not_to eq(second_calendar.slug)
      end

      it 'is idempotent when invoked again for the same community' do
        record = create(:better_together_community, name: 'Gamma Community')

        expect do
          record.send(:create_default_calendar)
        end.not_to(change { record.calendars.count })

        calendar = record.calendars.find_by!(identifier: "default-#{record.identifier}")
        expect(calendar.slug).to eq("default-#{record.identifier}")
      end
    end

    describe '#single_host_record' do
      it 'adds an error if host is set and another host community exists' do
        relation = double('ActiveRecord::Relation', exists?: true) # rubocop:todo RSpec/VerifiedDoubles
        allow(described_class).to receive(:where).and_return(relation)
        allow(relation).to receive(:not).and_return(relation)
        community.host = true
        community.valid?
        expect(community.errors[:host]).to include(I18n.t('errors.models.host_single'))
      end
    end
  end
end
