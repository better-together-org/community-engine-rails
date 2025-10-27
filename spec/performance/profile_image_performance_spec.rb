require 'rails_helper'

RSpec.describe 'Profile Image Performance', type: :request do
  include ActiveSupport::Testing::TimeHelpers

  before do
    configure_host_platform
  end

  context 'with multiple platform members' do
    let!(:platform) { create(:better_together_platform) }
    let!(:people) { create_list(:better_together_person, 3) } # Reduce to 3 for faster test
    let!(:role) { create(:better_together_role, :platform_role) } # Create platform role
    let!(:memberships) do
      people.map do |person|
        create(:better_together_person_platform_membership,
               joinable: platform,
               member: person,
               role: role) # Reuse the same platform role
      end
    end

    it 'loads platform show page efficiently with profile images' do
      # Measure execution time
      start_time = Time.current

      # Make request to platform show page
      get better_together.platform_path(platform, locale: I18n.default_locale)

      end_time = Time.current
      execution_time = end_time - start_time

      # Verify response is successful
      expect(response).to have_http_status(:success)

      # Log performance metrics (this will help track improvements)
      Rails.logger.info "Platform show page with #{people.count} members loaded in #{execution_time} seconds"

      # Performance expectation - should load in under 5 seconds
      expect(execution_time).to be < 5.seconds

      # Verify content includes member count (proving the associations loaded)
      expect(response.body).to include('membership-column')

      # Count the membership cards rendered
      membership_count = response.body.scan('membership-column').length
      expect(membership_count).to eq(people.count)
    end
  end

  context 'profile_image_url method performance' do
    let(:person) { create(:better_together_person) }

    it 'calls profile_image_url without errors when no image is attached' do
      start_time = Time.current

      # Call our optimized method (should return nil gracefully)
      result = person.profile_image_url(size: 150)

      end_time = Time.current
      execution_time = end_time - start_time

      expect(result).to be_nil

      # Should be reasonably fast (under 2 seconds for no image)
      expect(execution_time).to be < 2.seconds

      Rails.logger.info "profile_image_url method executed in #{execution_time} seconds"
    end
  end
end
