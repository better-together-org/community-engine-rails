#!/usr/bin/env ruby
# frozen_string_literal: true

# Generates db/community-engine-db.dbml from spec/dummy/db/schema.rb, the dumped schema of the engine.
# It reads the schema file with a small recorder instead of connecting to a database, so the output is
# deterministic and needs no Rails boot. Run through bin/export_schema_diagrams.
#
#   ruby scripts/export_schema_dbml.rb [--schema PATH] [--output PATH]

require 'json'
require 'optparse'
require 'pathname'

require_relative 'schema_dbml/active_record_stub'
require_relative 'schema_dbml/dbml_writer'
require_relative 'schema_dbml/schema_recorder'

options = { schema: 'spec/dummy/db/schema.rb', output: 'db/community-engine-db.dbml' }
OptionParser.new do |parser|
  parser.on('--schema PATH') { |value| options[:schema] = value }
  parser.on('--output PATH') { |value| options[:output] = value }
end.parse!

recorder = SchemaRecorder.new
schema_source = File.read(options[:schema])
Thread.current[:schema_recorder] = recorder
TOPLEVEL_BINDING.eval(schema_source, options[:schema])

output = Pathname.new(options[:output])
output.dirname.mkpath
output.write(DbmlWriter.new(recorder).to_s)
puts "Wrote #{options[:output]} (#{recorder.tables.size} tables, #{recorder.references.size} foreign keys)"
