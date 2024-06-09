# frozen_string_literal: true

# lib/tasks/importmap.rake

namespace :importmap do
  desc 'Generate importmap with digested assets'
  task generate: :environment do
    require 'json'
    importmap = {}
    controller_dir = Rails.root.join('public', 'assets', 'controllers')
    Dir.glob("#{controller_dir}/*.js").each do |file|
      filename = File.basename(file)
      original_name = filename.split('-').first
      importmap["controllers/#{original_name}"] = "/assets/controllers/#{filename}"
    end
    File.write(Rails.root.join('public', 'assets', 'importmap.json'), JSON.pretty_generate(importmap))
  end
end
