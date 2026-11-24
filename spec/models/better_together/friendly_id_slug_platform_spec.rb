# frozen_string_literal: true

require 'rails_helper'

# Slug rows carry the platform of their record, and the unique index on them is per platform.
RSpec.describe BetterTogether::FriendlyIdSlugPlatform do
  let!(:host_platform) { configure_host_platform }
  let(:other_platform) { create(:better_together_platform) }

  def slug_rows(record)
    FriendlyId::Slug.unscoped.where(sluggable_type: record.class.base_class.name, sluggable_id: record.id)
  end

  def insert_slug_row(platform_id:, sluggable_id: SecureRandom.uuid, slug: 'dup-slug')
    FriendlyId::Slug.unscoped.insert_all!([{ slug:, sluggable_id:, sluggable_type: 'BetterTogether::Page',
                                             locale: 'en', platform_id:, created_at: Time.current,
                                             updated_at: Time.current }])
  end

  describe 'platform on the slug row' do
    it 'copies the platform of the record on create', :aggregate_failures do
      page = create(:better_together_page, platform: other_platform, slug: 'copied-platform')

      expect(slug_rows(page).pluck(:platform_id).uniq).to eq([other_platform.id])
    end

    it 'copies the platform of the record on rename', :aggregate_failures do
      page = create(:better_together_page, platform: other_platform, slug: 'first-name')
      page.update!(slug: 'second-name')

      expect(slug_rows(page).pluck(:slug)).to contain_exactly('first-name', 'second-name')
      expect(slug_rows(page).pluck(:platform_id).uniq).to eq([other_platform.id])
    end
  end

  describe 'taking over a slug' do
    it 'evicts the stale history row of another event on the same platform', :aggregate_failures do
      old_owner = create(:better_together_event, platform: other_platform, identifier: 'open-night')
      old_owner.update!(identifier: 'closed-night')
      new_owner = create(:better_together_event, platform: other_platform, identifier: 'open-night')

      expect(slug_rows(old_owner).pluck(:slug)).to eq(['closed-night'])
      expect(slug_rows(new_owner).pluck(:slug)).to eq(['open-night'])
    end

    it 'keeps the history row of an event on another platform', :aggregate_failures do
      other_owner = create(:better_together_event, platform: other_platform, identifier: 'open-night')
      other_owner.update!(identifier: 'closed-night')
      host_owner = create(:better_together_event, platform: host_platform, identifier: 'open-night')

      expect(slug_rows(other_owner).pluck(:slug)).to contain_exactly('open-night', 'closed-night')
      expect(slug_rows(host_owner).pluck(:slug)).to eq(['open-night'])
    end
  end

  describe 'generated slugs' do
    it 'reserves a renamed page slug on its own platform', :aggregate_failures do
      old_owner = create(:better_together_page, platform: other_platform, slug: 'team-page')
      old_owner.update!(slug: 'team-us')
      newcomer = create(:better_together_page, platform: other_platform, slug: 'team-page')

      expect(newcomer.slug).to start_with('team-page-')
      expect(BetterTogether::Page.friendly_find_in_platform('team-page', platform: other_platform)).to eq(old_owner)
    end

    it 'does not reserve it against another platform', :aggregate_failures do
      other_owner = create(:better_together_page, platform: other_platform, slug: 'team-page')
      other_owner.update!(slug: 'team-us')
      host_page = create(:better_together_page, platform: host_platform, slug: 'team-page')

      expect(host_page.slug).to eq('team-page')
    end
  end

  describe 'unique index' do
    it 'rejects the same slug twice on one platform' do
      insert_slug_row(platform_id: other_platform.id)

      expect { insert_slug_row(platform_id: other_platform.id) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'rejects the same slug twice without a platform (the old index never did)' do
      insert_slug_row(platform_id: nil)

      expect { insert_slug_row(platform_id: nil) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'allows the same slug on two platforms', :aggregate_failures do
      insert_slug_row(platform_id: other_platform.id)

      expect { insert_slug_row(platform_id: host_platform.id) }.not_to raise_error
    end
  end

  describe 'slug validation for platform-scoped models' do
    it 'lets two platforms share a person slug and still rejects a repeat on one platform', :aggregate_failures do
      create(:better_together_person, platform: host_platform, identifier: 'shared-handle')

      other = build(:better_together_person, platform: other_platform, identifier: 'shared-handle-b', slug: 'shared-handle')
      same = build(:better_together_person, platform: host_platform, identifier: 'shared-handle-c', slug: 'shared-handle')

      expect(other).to be_valid
      expect(same).not_to be_valid
      expect(same.errors[:slug]).to be_present
    end
  end
end
