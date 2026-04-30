# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationNotifier do
  it 'provides notification partials for every concrete notifier' do
    notifier_root = Rails.root.join('app/notifiers/better_together')
    view_root = Rails.root.join('app/views/better_together')

    missing = notifier_root.glob('**/*_notifier.rb').filter_map do |path|
      relative = path.relative_path_from(notifier_root)
      next if relative.to_s == 'invitation_notifier_base.rb'

      partial = view_root.join(relative.sub_ext(''), 'notifications/_notification.html.erb')
      relative.to_s unless partial.exist?
    end

    expect(missing).to eq([])
  end
end
