# db/seeds.

# Invoke the task to generate navigation data
begin
  Rake::Task['better_together:generate_navigation'].invoke
rescue RuntimeError => e
  Rake::Task['app:better_together:generate_navigation'].invoke
end

# Invoke the task to generate setup wizard 
begin
  Rake::Task['better_together:generate_setup_wizard'].invoke
rescue RuntimeError => e
  Rake::Task['app:better_together:generate_setup_wizard'].invoke
end
