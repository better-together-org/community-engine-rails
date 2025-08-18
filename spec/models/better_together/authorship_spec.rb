# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe Authorship, type: :model do
    describe 'notifications on add' do
      let(:person) { create(:person) }
      let(:page)   { create(:page) }

      around do |ex|
        prev = defined?(::Current) && ::Current.respond_to?(:person) ? ::Current.person : nil
        ::Current.person = person if defined?(::Current)
        ex.run
        ::Current.person = prev if defined?(::Current)
      end

      it 'does not notify when current_person adds themselves' do
        expect do
          BetterTogether::Authorship.with_creator(person) do
            page.authorships.create!(author: person)
          end
        end.not_to(change { Noticed::Notification.count })
      end

      it 'notifies when current_person adds someone else' do
        other = create(:person)
        expect do
          BetterTogether::Authorship.with_creator(person) do
            page.authorships.create!(author: other)
          end
        end.to(change { Noticed::Notification.count }.by(1))
      end
    end
  end

  RSpec.describe Authorship, type: :model do # rubocop:todo Metrics/BlockLength
    describe 'notifications on remove' do # rubocop:todo Metrics/BlockLength
      let(:page)   { create(:page) }
      let(:person) { create(:person) }

      before do
        # Ensure person is an author on the page first
        other = create(:person)
        BetterTogether::Authorship.with_creator(other) do
          page.authorships.create!(author: person)
        end
      end

      it 'does not notify when current_person removes themselves' do
        prev = defined?(::Current) && ::Current.respond_to?(:person) ? ::Current.person : nil
        ::Current.person = person if defined?(::Current)

        expect do
          BetterTogether::Authorship.with_creator(person) do
            page.authorships.find_by!(author: person).destroy!
          end
        end.not_to(change { Noticed::Notification.count })

        ::Current.person = prev if defined?(::Current)
      end

      it 'notifies when someone else removes the author' do
        other = create(:person)
        prev = defined?(::Current) && ::Current.respond_to?(:person) ? ::Current.person : nil
        ::Current.person = other if defined?(::Current)

        expect do
          BetterTogether::Authorship.with_creator(other) do
            page.authorships.find_by!(author: person).destroy!
          end
        end.to(change { Noticed::Notification.count }.by(1))

        ::Current.person = prev if defined?(::Current)
      end
    end
  end
end
