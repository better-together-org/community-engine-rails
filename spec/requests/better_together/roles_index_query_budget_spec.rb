# frozen_string_literal: true

require 'rails_helper'

# Each role card summarises its permissions; that must come from the preloaded association, so adding roles does not
# add queries.
RSpec.describe 'Roles index query budget', :as_platform_manager do
  let(:locale) { I18n.default_locale }

  def roles_index_query_count
    count = 0
    counter = lambda do |_name, _start, _finish, _id, payload|
      count += 1 unless %w[SCHEMA TRANSACTION].include?(payload[:name]) || payload[:sql].match?(/\A\s*(BEGIN|COMMIT|SAVEPOINT|RELEASE)/)
    end
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') do
      get better_together.roles_path(locale:)
    end
    count
  end

  def create_roles(number, offset)
    permissions = create_list(:better_together_resource_permission, 3)
    number.times do |i|
      create(:better_together_role, resource_type: 'BetterTogether::Community', name: "Query Role #{offset + i}",
                                    resource_permissions: permissions)
    end
  end

  it 'does not add queries for each extra role', :aggregate_failures do
    create_roles(3, 0)
    roles_index_query_count # warm caches
    few = roles_index_query_count
    create_roles(8, 10)
    many = roles_index_query_count

    expect(response).to have_http_status(:ok)
    expect(many - few).to be <= 2
  end
end
