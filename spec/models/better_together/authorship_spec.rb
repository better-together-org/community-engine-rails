# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Authorship do
  describe 'polymorphic author support' do
    let(:page) { create(:page) }
    let(:robot) { create(:robot, platform: page.platform) }

    it 'supports a robot author' do
      authorship = described_class.create!(author: robot, authorable: page)

      expect(authorship.author).to eq(robot)
      expect(authorship.author_type).to eq('BetterTogether::Robot')
      expect(page.robot_authors).to include(robot)
      expect(page.governed_authors).to include(robot)
    end

    it 'defaults new contribution records to author/content' do
      page = create(:page)
      person = create(:person)

      contribution = described_class.create!(author: person, authorable: page)

      expect(contribution.role).to eq('author')
      expect(contribution.contribution_type).to eq('content')
      expect(contribution).to be_author_role
    end

    it 'supports non-author contribution roles and types' do
      post = create(:post)
      person = create(:person)

      contribution = described_class.create!(
        author: person,
        authorable: post,
        role: 'reviewer',
        contribution_type: 'documentation',
        details: { source: 'github', pull_request: 1494 }
      )

      expect(contribution.role).to eq('reviewer')
      expect(contribution.contribution_type).to eq('documentation')
      expect(contribution.details).to include('source' => 'github', 'pull_request' => 1494)
      expect(post.contributors_for(:reviewer)).to include(person)
      expect(person.contributed_posts).to include(post)
      expect(person.authored_posts).not_to include(post)
    end

    it 'merges github source mappings into a single governed contribution record' do
      page = create(:page)
      person = create(:person)

      described_class.create!(
        author: person,
        authorable: page,
        role: 'author',
        contribution_type: 'code',
        details: {
          source: 'github',
          github_sources: [
            {
              reference_key: 'pull_request_1494',
              source_kind: 'pull_request',
              pull_request_number: 1494
            }
          ]
        }
      )

      contribution = BetterTogether::GithubContributionImportService.new(
        record: page,
        contributor: person,
        source: {
          reference_key: 'commit_abc123',
          source_kind: 'commit',
          title: 'Add governance bundle links',
          source_url: 'https://github.com/better-together-org/community-engine-rails/commit/abc123',
          metadata: {
            commit_sha: 'abc123',
            repository_name: 'better-together-org/community-engine-rails'
          }
        }
      ).import!

      expect(contribution.details['github_sources'].size).to eq(2)
      expect(contribution.details['github_sources'].last['commit_sha']).to eq('abc123')
    end

    it 'does not notify robots when they are added to a page' do
      expect do
        page.authorships.create!(author: robot)
      end.not_to(change(Noticed::Notification, :count))
    end
  end

  describe 'notifications on add' do
    let(:person) { create(:person) }
    let(:page)   { create(:page) }

    around do |ex|
      prev = defined?(Current) && Current.respond_to?(:person) ? Current.person : nil
      Current.person = person if defined?(Current)
      ex.run
      Current.person = prev if defined?(Current)
    end

    it 'does not notify when current_person adds themselves' do
      expect do
        described_class.with_creator(person) do
          page.authorships.create!(author: person)
        end
      end.not_to(change(Noticed::Notification, :count))
    end

    it 'notifies when current_person adds someone else' do
      other = create(:person)
      expect do
        described_class.with_creator(person) do
          page.authorships.create!(author: other)
        end
      end.to(change(Noticed::Notification, :count).by(1))
    end
  end

  describe 'notifications on remove' do
    let(:page)   { create(:page) }
    let(:person) { create(:person) }

    before do
      # Ensure person is an author on the page first
      other = create(:person)
      described_class.with_creator(other) do
        page.authorships.create!(author: person)
      end
    end

    it 'does not notify when current_person removes themselves' do
      prev = defined?(Current) && Current.respond_to?(:person) ? Current.person : nil
      Current.person = person if defined?(Current)

      expect do
        described_class.with_creator(person) do
          page.authorships.find_by!(author: person).destroy!
        end
      end.not_to(change(Noticed::Notification, :count))

      Current.person = prev if defined?(Current)
    end

    it 'notifies when someone else removes the author' do
      other = create(:person)
      prev = defined?(Current) && Current.respond_to?(:person) ? Current.person : nil
      Current.person = other if defined?(Current)

      expect do
        described_class.with_creator(other) do
          page.authorships.find_by!(author: person).destroy!
        end
      end.to(change(Noticed::Notification, :count).by(1))

      Current.person = prev if defined?(Current)
    end
  end
end
