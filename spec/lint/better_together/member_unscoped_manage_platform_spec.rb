# frozen_string_literal: true

require 'rails_helper'

# A bare permitted_to?('manage_platform') unions the permission across every platform the
# person belongs to. Use platform_manager? / host_platform_manager? or pass the platform.
RSpec.describe BetterTogether::Member do
  let(:allowed) do
    {
      # Safety exemption, not authorization: anyone managing any platform cannot be blocked.
      'app/models/better_together/person_block.rb' => 1,
      'app/policies/better_together/person_block_policy.rb' => 1
    }
  end

  it 'unscoped manage_platform checks stay within the reviewed allowlist' do
    root = BetterTogether::Engine.root
    pattern = /permitted_to\?\(\s*['":]manage_platform['"]?\s*\)/
    found = Dir[root.join('{app,lib,config}/**/*.rb')].filter_map do |path|
      code = File.readlines(path).reject { |line| line.strip.start_with?('#') }.join
      count = code.scan(pattern).size
      [path.delete_prefix("#{root}/"), count] if count.positive?
    end.to_h

    expect(found).to eq(allowed)
  end
end
