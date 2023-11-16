# lib/tasks/better_together_tasks.rake
namespace :better_together do
  desc "Load seed data for BetterTogether"
  task load_seed: :environment do
    load BetterTogether::Engine.root.join('db', 'seeds.rb')
  end
end
