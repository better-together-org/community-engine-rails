# db/seeds.

# Invoke the task to generate navigation and page data
begin
  Rake::Task['better_together:generate_navigation_and_pages'].invoke
rescue RuntimeError => e
  Rake::Task['app:better_together:generate_navigation_and_pages'].invoke
end

# Invoke the task to generate setup wizard 
begin
  Rake::Task['better_together:generate_setup_wizard'].invoke
rescue RuntimeError => e
  Rake::Task['app:better_together:generate_setup_wizard'].invoke
end
