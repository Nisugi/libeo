# frozen_string_literal: true

desc 'Build the libeo gem into dist/'
task :gem do
  require 'fileutils'
  require 'rubygems/package'
  spec = Gem::Specification.load(File.join(__dir__, 'libeo.gemspec'))
  FileUtils.mkdir_p(File.join(__dir__, 'dist'))
  Dir.chdir(__dir__) do
    file = Gem::Package.build(spec)
    FileUtils.mv(file, File.join('dist', file))
    puts "built dist/#{file} (#{spec.files.size} files)"
  end
end

desc 'Remove dist/'
task :clean do
  require 'fileutils'
  FileUtils.rm_rf(File.join(__dir__, 'dist'))
end

task default: :gem

begin
  require 'yard'
  YARD::Rake::YardocTask.new(:doc) do |t|
    t.options = [] # everything is in .yardopts
  end
rescue LoadError
  desc 'YARD is not installed'
  task :doc do
    abort 'yard is not installed: bundle install'
  end
end
