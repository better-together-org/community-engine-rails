# frozen_string_literal: true

# Writes docs/diagrams/source/ce_localized_attributes.mmd from live Mobility reflection.
# Run through bin/export_localized_attributes. Flags:
#   --check   write nothing; exit 1 when the committed diagram is stale or any translates call is untyped or names its attributes dynamically
require 'pathname'
require_relative 'localized_attribute_diagram'

Rails.application.eager_load!

root = BetterTogether::Engine.root.to_s
output = File.join(root, 'docs/diagrams/source/ce_localized_attributes.mmd')
models = ActiveRecord::Base.descendants.select { |m| m.name && !m.abstract_class? && m.respond_to?(:mobility_attributes) }
declarations = LocalizedAttributeDiagram::Scanner.scan_roots([root], base: root)
diagram = LocalizedAttributeDiagram.new(models: models, declarations: declarations, title: 'Community Engine')

untyped = diagram.untyped_declarations
untyped.each { |d| warn "UNTYPED translates (add type: :string or :text): #{d.location} #{d.attributes.join(', ')}" }
# translates(*NAMES) names no attributes, so it can be neither drawn nor type-checked.
dynamic = diagram.unresolved.select(&:dynamic)
dynamic.each { |d| warn "DYNAMIC translates (list the attributes as symbols so they can be drawn): #{d.location}" }
problems = untyped.size + dynamic.size
diagram.unresolved.each { |d| warn "Could not attribute translates call: #{d.location} #{d.attributes.join(', ')}" }

if ARGV.include?('--check')
  warn "#{output} is stale. Run bin/export_localized_attributes and commit it." unless diagram.current?(output)
  exit(diagram.current?(output) && problems.zero? ? 0 : 1)
end

File.write(output, diagram.to_mermaid)
puts "Wrote #{Pathname.new(output).relative_path_from(Pathname.new(root))} (#{diagram.entries.size} attributes)"
exit(problems.zero? ? 0 : 1)
