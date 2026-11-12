# frozen_string_literal: true

require 'tmpdir'
require_relative 'spec_helper'
require_relative '../lib/libeo/install'

RSpec.describe LibEO::Install do
  around do |example|
    Dir.mktmpdir('libeo-install') do |dir|
      @directory = dir
      example.run
    end
  end

  # A directory that looks like a Lich install.
  def lich(name = 'Lich5', version: '5.22.0')
    dir = File.join(@directory, name)
    FileUtils.mkdir_p(File.join(dir, 'scripts'))
    FileUtils.mkdir_p(File.join(dir, 'lib'))
    File.write(File.join(dir, 'lich.rbw'), '')
    File.write(File.join(dir, 'lib', 'version.rb'), "LICH_VERSION = '#{version}'\n") if version
    dir
  end

  # A small scripts/ tree standing in for the gem's.
  def payload(version: '1.0.0', parts: %w[help.rb travel.rb])
    root = File.join(@directory, "payload-#{version}")
    FileUtils.mkdir_p(File.join(root, 'eo', 'guild'))
    File.write(File.join(root, 'libeo.lic'), "=begin\n      required: Lich >= 5.22.0\n=end\n")
    File.write(File.join(root, 'eo', 'version.rb'), "  VERSION = '#{version}'.freeze\n")
    File.write(File.join(root, 'eo', 'guild', 'tables.rb'), "# tables\n")
    File.write(File.join(root, 'README.md'), "# not shipped\n")
    parts.each { |part| File.write(File.join(root, 'eo', part), "# #{part}\n") }
    root
  end

  describe 'the payload the real gem carries' do
    it 'is the loader and the eo/ files, nothing else' do
      files = described_class.payload_files
      expect(files).to include('libeo.lic', 'eo/version.rb', 'eo/guild/tables.rb')
      expect(files.grep(/\Aeo\/|\Alibeo\.lic\z/)).to eq(files)
    end

    it 'takes its version from eo/version.rb and its Lich requirement from the loader header' do
      expect(described_class.version).to match(/\A\d+\.\d+\.\d+\z/)
      expect(described_class.required_lich).to eq('5.22.0')
    end
  end

  describe '.find_lich' do
    it 'takes --lich-dir when it is a Lich install, and refuses when it is not' do
      dir = lich
      expect(described_class.find_lich(explicit: dir, candidates: [])).to eq(File.expand_path(dir))
      expect { described_class.find_lich(explicit: @directory, candidates: []) }
        .to raise_error(described_class::Error, /--lich-dir .* is not a Lich install/)
    end

    it 'finds the one candidate that is a Lich install, and asks when there are several or none' do
      only = lich
      expect(described_class.find_lich(env: nil, candidates: [File.join(@directory, 'nope'), only])).to eq(File.expand_path(only))
      other = lich('lich')
      expect { described_class.find_lich(env: nil, candidates: [only, other]) }
        .to raise_error(described_class::Error, /several Lich installs/)
      expect { described_class.find_lich(env: nil, candidates: []) }
        .to raise_error(described_class::Error, /no Lich install found/)
    end
  end

  describe '.install' do
    it 'copies the payload into scripts/, records it, and leaves data/ alone' do
      dir = lich
      FileUtils.mkdir_p(File.join(dir, 'data'))
      File.write(File.join(dir, 'data', 'keep.yaml'), 'mine')
      result = described_class.install(dir, root: payload)
      expect(result[:version]).to eq('1.0.0')
      expect(File.read(File.join(dir, 'scripts', 'eo', 'travel.rb'))).to eq("# travel.rb\n")
      expect(File).to exist(File.join(dir, 'scripts', 'libeo.lic'))
      expect(File).to exist(File.join(dir, 'scripts', 'eo', 'guild', 'tables.rb'))
      expect(File).not_to exist(File.join(dir, 'scripts', 'README.md'))
      expect(described_class.manifest(dir)['files'].keys).to match_array(result[:copied])
      expect(File.read(File.join(dir, 'data', 'keep.yaml'))).to eq('mine')
    end

    it 'removes on upgrade a file the newer version dropped, and only that' do
      dir = lich
      described_class.install(dir, root: payload(version: '1.0.0', parts: %w[help.rb travel.rb old.rb]))
      File.write(File.join(dir, 'scripts', 'eo', 'mine.rb'), 'not installed by the gem')
      result = described_class.install(dir, root: payload(version: '1.1.0', parts: %w[help.rb travel.rb]))
      expect(result[:removed]).to eq(['eo/old.rb'])
      expect(File).not_to exist(File.join(dir, 'scripts', 'eo', 'old.rb'))
      expect(File).to exist(File.join(dir, 'scripts', 'eo', 'mine.rb'))
      expect(described_class.manifest(dir)['version']).to eq('1.1.0')
    end

    it 'refuses a directory that is not a Lich install' do
      expect { described_class.install(@directory, root: payload) }.to raise_error(described_class::Error, /not a Lich install/)
    end
  end

  describe '.uninstall and .check' do
    it 'removes exactly the recorded files and the empty directories they leave' do
      dir = lich
      described_class.install(dir, root: payload)
      removed = described_class.uninstall(dir)
      expect(removed).to include('libeo.lic', 'eo/version.rb')
      expect(File).not_to exist(File.join(dir, 'scripts', 'eo'))
      expect(described_class.manifest(dir)).to be_nil
      expect { described_class.uninstall(dir) }.to raise_error(described_class::Error, /no libeo install recorded/)
    end

    it 'reports missing and changed files' do
      dir = lich
      described_class.install(dir, root: payload)
      File.delete(File.join(dir, 'scripts', 'eo', 'help.rb'))
      File.write(File.join(dir, 'scripts', 'eo', 'travel.rb'), 'edited')
      state = described_class.check(dir)
      expect(state[:version]).to eq('1.0.0')
      expect(state[:missing]).to eq(['eo/help.rb'])
      expect(state[:changed]).to eq(['eo/travel.rb'])
      expect(described_class.check(lich('other'))).to be_nil
    end
  end

  describe '.lich_supported?' do
    it 'compares the Lich found with what the loader requires' do
      expect(described_class.lich_supported?(lich('new', version: '5.22.0'), payload)).to be(true)
      expect(described_class.lich_supported?(lich('old', version: '5.21.9'), payload)).to be(false)
      expect(described_class.lich_supported?(lich('unknown', version: nil), payload)).to be_nil
    end
  end
end
