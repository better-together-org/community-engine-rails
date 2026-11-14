# frozen_string_literal: true

require 'generator_spec'
require 'rails_helper'
require 'tmpdir'
require BetterTogether::Engine.root.join('lib/generators/better_together/install/install_generator')

RSpec.describe BetterTogether::InstallGenerator, type: :generator do
  around do |example|
    tmp_dir = Dir.mktmpdir('bt-install-generator-')
    self.class.destination(tmp_dir)
    prepare_destination
    example.run
  ensure
    FileUtils.rm_rf(tmp_dir) if tmp_dir
  end

  def write_host_files
    root = destination_root
    FileUtils.mkdir_p([File.join(root, 'config'), File.join(root, 'app/assets/config')])
    {
      'config/routes.rb' => "Rails.application.routes.draw do\nend\n",
      'config/storage.yml' => "local:\n  service: Disk\n",
      'config/application.rb' => "module Host\n  class Application < Rails::Application\n  end\nend\n",
      'app/assets/config/manifest.js' => "//= link_tree ../images\n"
    }.each { |path, body| File.write(File.join(root, path), body) }
  end

  it 'installs the full host setup in gem mode' do
    write_host_files
    run_generator

    assert_file 'config/initializers/better_together.rb', /host_migrations_mode = :gem/
    assert_file 'config/routes.rb', %r{mount BetterTogether::Engine => '/'}
    assert_file 'config/storage.yml', /^s3_compatible:/
    assert_file 'config/application.rb', /primary_key_type: :uuid/
    assert_file 'config/application.rb', /fixture_replacement :factory_bot/
    assert_file 'config/initializers/better_together_hosts.rb', /config\.hosts/
    assert_file 'config/initializers/better_together_head_tags.rb', /register_head_tag_provider/
    assert_file 'app/assets/config/manifest.js', %r{link_tree \.\./\.\./javascript \.js}
    assert_file 'app/assets/stylesheets/host_theme.scss'
    expect(File.executable?(File.join(destination_root, 'bin/check-engine-migrations'))).to be(true)
  end

  it 'records the install migrations mode' do
    write_host_files
    run_generator %w[--migrations=install]

    assert_file 'config/initializers/better_together.rb', /host_migrations_mode = :install/
  end

  it 'is idempotent' do
    write_host_files
    run_generator
    run_generator

    expect(File.read(File.join(destination_root, 'config/routes.rb')).scan('BetterTogether::Engine').size).to eq(1)
    expect(File.read(File.join(destination_root, 'config/storage.yml')).scan('s3_compatible:').size).to eq(1)
    expect(File.read(File.join(destination_root, 'config/application.rb')).scan('config.generators').size).to eq(1)
  end

  it 'honours the skip options' do
    write_host_files
    run_generator %w[--skip-routes --skip-storage --skip-assets --skip-generators --skip-ci-check]

    assert_file 'config/routes.rb', /\A(?!.*BetterTogether).*\z/m
    assert_no_file 'bin/check-engine-migrations'
    assert_no_file 'app/assets/stylesheets/host_theme.scss'
  end

  it 'check script fails on copied engine migrations' do
    write_host_files
    run_generator
    FileUtils.mkdir_p(File.join(destination_root, 'db/migrate'))
    FileUtils.touch(File.join(destination_root, 'db/migrate/20240101000000_x.better_together.rb'))
    script = File.join(destination_root, 'bin/check-engine-migrations')

    expect(system(script, chdir: destination_root, out: File::NULL, err: File::NULL)).to be(false)
    FileUtils.rm_f(Dir[File.join(destination_root, 'db/migrate/*')])
    expect(system(script, chdir: destination_root, out: File::NULL)).to be(true)
  end
end
