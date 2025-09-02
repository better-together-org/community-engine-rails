# frozen_string_literal: true

# lib/tasks/importmap.rake

namespace :importmap do
  desc 'Generate importmap with digested assets'
  task generate: :environment do
    require 'json'
    importmap = {}
    controller_dir = Rails.public_path.join('assets/controllers')
    Dir.glob("#{controller_dir}/*.js").each do |file|
      filename = File.basename(file)
      original_name = filename.split('-').first
      importmap["controllers/#{original_name}"] = "/assets/controllers/#{filename}"
    end
    File.write(Rails.public_path.join('assets/importmap.json'), JSON.pretty_generate(importmap))
  end
end
