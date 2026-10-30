# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Quotas::OwnerResolver, type: :service do
  describe '.resolve' do
    context 'when the record is itself a quota owner' do
      it 'returns a Person directly' do
        person = create(:better_together_person)
        expect(described_class.resolve(person)).to eq(person)
      end

      it 'returns a Community directly' do
        community = create(:better_together_community)
        expect(described_class.resolve(community)).to eq(community)
      end

      it 'returns a Platform directly' do
        platform = create(:better_together_platform)
        expect(described_class.resolve(platform)).to eq(platform)
      end
    end

    context 'when the record has a creator' do
      it 'returns the creator' do
        creator = create(:better_together_person)
        upload = create(:better_together_upload, creator:)
        expect(described_class.resolve(upload)).to eq(creator)
      end
    end

    context 'when the record has an initiator (creator-equivalent)' do
      it 'returns the initiator' do
        initiator = create(:better_together_person)
        log = create(:ai_log_translation, initiator:)
        expect(described_class.resolve(log)).to eq(initiator)
      end
    end

    context 'when the record has no creator but has a community' do
      it 'returns the community' do
        community = create(:better_together_community)
        post = create(:better_together_post, creator: nil, community:)
        expect(described_class.resolve(post)).to eq(community)
      end
    end

    context 'when the record has no creator or community but has a platform' do
      it 'returns the platform' do
        platform = create(:better_together_platform)
        upload = create(:better_together_upload, creator: nil, platform:)
        expect(described_class.resolve(upload)).to eq(platform)
      end
    end

    context 'when the record is an ActionText::RichText join row' do
      it 'resolves through to the record it is actually embedded in' do
        creator = create(:better_together_person)
        upload = create(:better_together_upload, creator:)
        upload.update!(description: 'some rich text')
        rich_text = upload.rich_text_description

        expect(rich_text).to be_a(ActionText::RichText)
        expect(described_class.resolve(rich_text)).to eq(creator)
      end
    end

    context 'when nothing resolves at all' do
      it 'falls back to the host platform' do
        host_platform = BetterTogether::Platform.find_by(host: true) ||
                        create(:better_together_platform, host: true)
        expect(described_class.resolve(nil)).to eq(host_platform)
      end
    end

    context 'with a named hop model (not PlatformRecord, no platform fallback of its own)' do
      it 'resolves BetterTogether::PlatformInvitation through its inviter' do
        inviter = create(:better_together_person)
        invitation = create(:better_together_platform_invitation, inviter:)

        expect(described_class.resolve(invitation)).to eq(inviter)
      end
    end
  end
end
