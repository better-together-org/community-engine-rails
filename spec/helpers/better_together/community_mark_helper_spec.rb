# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe CommunityMarkHelper do
    let(:svg) { '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"></svg>' }
    let(:community) { create(:better_together_community) }

    before { helper.extend(BetterTogether::ImageHelper, BetterTogether::ApplicationHelper) }

    def attach(name)
      community.public_send(name).attach(io: StringIO.new(svg), filename: "#{name}.svg", content_type: 'image/svg+xml')
    end

    describe '#community_mark' do
      it 'is nil with neither image' do
        expect(helper.community_mark(community)).to be_nil
      end

      it 'prefers the logo over the profile image', :aggregate_failures do
        attach(:profile_image)
        expect(helper.community_mark(community).first).to eq(:profile_image)

        attach(:logo)
        expect(helper.community_mark(community).first).to eq(:logo)
      end
    end

    describe '#community_mark_tag' do
      it 'renders a logo as a sized tile', :aggregate_failures do
        attach(:logo)
        html = helper.community_mark_tag(community, size: 20, alt: 'Name')

        expect(html).to include('community-mark-tile', '--mark-size: 20px')
      end

      it 'renders the round profile image without a logo' do
        attach(:profile_image)

        expect(helper.community_mark_tag(community, size: 20, alt: 'Name')).to include('rounded-circle')
      end

      it 'renders the round profile image for a person' do
        person = create(:better_together_person)

        expect(helper.community_mark_tag(person, size: 20, alt: 'Name')).to include('rounded-circle')
      end
    end
  end
end
