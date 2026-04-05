# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Authorship do
  describe 'polymorphic authors' do
    it 'supports robot authorship records' do
      page = create(:page)
      robot = create(:robot, platform: page.platform)

      authorship = page.authorships.create!(author: robot)

      expect(authorship.author).to eq(robot)
      expect(authorship.author_type).to eq('BetterTogether::Robot')
    end

    it 'does not notify robots when they are added to a page' do
      page = create(:page)
      robot = create(:robot, platform: page.platform)

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
