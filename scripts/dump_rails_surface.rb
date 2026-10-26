# frozen_string_literal: true

# Dumps the live Rails surface (engine routes, models, controllers, screenshot URL recognition) to
# tmp/rails_surface.json for scripts/export_documentation_coverage_manifest.rb. Needs no database.
# Run through bin/export_documentation_coverage_manifest, which wraps it in bin/dc-run-dummy.

require 'json'
require 'pathname'

Rails.application.eager_load!

project_root = Pathname.new(__dir__).join('..').expand_path
engine_routes = BetterTogether::Engine.routes

routes = engine_routes.routes.filter_map do |route|
  controller = route.defaults[:controller]
  action = route.defaults[:action]
  next if controller.blank? || action.blank?

  {
    'verb' => route.verb.to_s,
    'path' => route.path.spec.to_s,
    'name' => route.name,
    'controller' => controller,
    'action' => action
  }
end

models = ActiveRecord::Base.descendants.filter_map do |klass|
  next if klass.name.blank? || !klass.name.start_with?('BetterTogether::') || klass.abstract_class?

  parent_modules = klass.superclass.respond_to?(:included_modules) ? klass.superclass.included_modules : []
  own_concerns = (klass.included_modules - parent_modules).filter_map do |mod|
    mod.name if mod.name&.start_with?('BetterTogether::') && !mod.is_a?(Class)
  end

  {
    'name' => klass.name,
    'table' => klass.table_name,
    'superclass' => klass.superclass.name,
    'file' => Object.const_source_location(klass.name)&.first,
    'concerns' => own_concerns.sort
  }
end

controllers = ActionController::Base.descendants.filter_map do |klass|
  next if klass.name.blank? || !klass.name.start_with?('BetterTogether::')

  {
    'name' => klass.name,
    'controller_path' => klass.controller_path,
    'file' => Object.const_source_location(klass.name)&.first,
    'actions' => klass.action_methods.to_a.sort
  }
end

screenshot_routes = {}
Dir[project_root.join('docs/screenshots/**/*.json').to_s].each do |sidecar|
  data = JSON.parse(File.read(sidecar))
  url = data['url'].to_s.sub(%r{\Ahttps?://[^/]+}, '').split('?').first
  next if url.blank?

  # Journey matching only: recognize_path would run Devise route constraints that need a Warden request.
  matched = engine_routes.routes.find do |route|
    route.defaults[:controller].present? && route.verb.to_s.include?('GET') && route.path.match?(url)
  end
  recognized = matched && { controller: matched.defaults[:controller], action: matched.defaults[:action] }
  screenshot_routes[Pathname.new(sidecar).relative_path_from(project_root).to_s] = {
    'url' => data['url'], 'source_spec' => data['source_spec'], 'flow' => data['flow'], 'role' => data['role'],
    'controller' => recognized && recognized[:controller], 'action' => recognized && recognized[:action]
  }
rescue JSON::ParserError
  next
end

out = project_root.join('tmp/rails_surface.json')
FileUtils.mkdir_p(out.dirname)
File.write(out, JSON.pretty_generate('routes' => routes, 'models' => models, 'controllers' => controllers,
                                     'screenshot_routes' => screenshot_routes))
puts "rails surface: #{routes.size} routes, #{models.size} models, #{controllers.size} controllers, " \
     "#{screenshot_routes.size} screenshot sidecars -> #{out.relative_path_from(project_root)}"
