require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = 'rack-perftools_profiler'
    gem.summary = %Q{Middleware for profiling Rack-compatible apps using perftools.rb}
    gem.description = %Q{Middleware for profiling Rack-compatible apps using perftools.rb}
    gem.email = 'ben@bbrinck.com'
    gem.homepage = 'http://github.com/bhb/rack-perftools_profiler'
    gem.authors = ['Ben Brinckerhoff']
    gem.add_dependency 'perftools.rb', '~> 0.4'
    gem.add_dependency 'rack', '~> 1.0'
    gem.add_dependency('open4', '~> 1.0')
    gem.add_development_dependency 'rack', '~> 1.1'
    gem.add_development_dependency 'shoulda', '~> 2.10'
    gem.add_development_dependency 'mocha', '~> 0.9'
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: sudo gem install jeweler"
end

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/*_test.rb'
  test.verbose = true
end

begin
  require 'rcov/rcovtask'
  Rcov::RcovTask.new do |test|
    test.libs << 'test'
    test.pattern = 'test/**/*_test.rb'
    test.verbose = true
  end
rescue LoadError
  task :rcov do
    abort "RCov is not available. In order to run rcov, you must: sudo gem install spicycode-rcov"
  end
end

task :test => :check_dependencies

task :default => :test

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  if File.exist?('VERSION')
    version = File.read('VERSION')
  else
    version = ""
  end

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "rack-perftools_profiler #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
