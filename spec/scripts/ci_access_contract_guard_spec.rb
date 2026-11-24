# frozen_string_literal: true

require 'rails_helper'
require 'open3'
require 'tmpdir'

RSpec.describe 'bin/ci-access-contract-guard' do # rubocop:disable RSpec/DescribeClass
  let(:script) { BetterTogether::Engine.root.join('bin/ci-access-contract-guard').to_s }
  let(:dir) { Dir.mktmpdir('access-guard') }

  after { FileUtils.remove_entry(dir) }

  def git(*)
    out, status = Open3.capture2e('git', '-C', dir, '-c', 'user.name=t', '-c', 'user.email=t@example.test',
                                  '-c', 'commit.gpgsign=false', *)
    raise out unless status.success?

    out
  end

  def write(path, content)
    full = File.join(dir, path)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, content)
  end

  def run_guard(body: nil)
    git('add', '-A')
    git('commit', '-qm', 'change')
    args = ['--base-ref', 'base', '--head-ref', 'HEAD']
    if body
      write('body.md', body)
      args += ['--pr-body-file', File.join(dir, 'body.md')]
    end
    Open3.capture3(script, *args, chdir: dir)
  end

  before do
    git('init', '-q', '-b', 'main')
    write('README.md', "x\n")
    write('app/controllers/things_controller.rb', "class ThingsController\n  def show; authorize @t; end\nend\n")
    git('add', '-A')
    git('commit', '-qm', 'base')
    git('tag', 'base')
  end

  it 'passes when no surface changed' do
    write('docs/a.md', "a\n")
    _out, _err, status = run_guard
    expect(status).to be_success
  end

  it 'fails when a policy changes without the contract' do
    write('app/policies/better_together/thing_policy.rb', "class ThingPolicy; end\n")
    _out, err, status = run_guard
    expect(status.exitstatus).to eq(1)
    expect(err).to include('thing_policy.rb')
  end

  it 'fails when a controller authorize line changes' do
    write('app/controllers/things_controller.rb', "class ThingsController\n  def show; skip_authorization; end\nend\n")
    _out, _err, status = run_guard
    expect(status.exitstatus).to eq(1)
  end

  it 'ignores controller changes that do not touch authorization' do
    write('app/controllers/things_controller.rb',
          "class ThingsController\n  def show; authorize @t; end\n  def index; end\nend\n")
    _out, _err, status = run_guard
    expect(status).to be_success
  end

  it 'passes when the contract is updated in the same change' do
    write('app/policies/better_together/thing_policy.rb', "class ThingPolicy; end\n")
    write('config/access_contracts/things.yml', "a: 1\n")
    _out, _err, status = run_guard
    expect(status).to be_success
  end

  it 'passes with a stated exemption of sufficient length' do
    write('app/policies/better_together/thing_policy.rb', "class ThingPolicy; end\n")
    _out, _err, status = run_guard(body: "access contract: unchanged because only a comment was reworded\n")
    expect(status).to be_success
  end

  it 'rejects an exemption with no reason' do
    write('app/policies/better_together/thing_policy.rb', "class ThingPolicy; end\n")
    _out, _err, status = run_guard(body: "access contract: unchanged because n/a\n")
    expect(status.exitstatus).to eq(1)
  end
end
