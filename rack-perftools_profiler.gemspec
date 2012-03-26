$:.push File.expand_path("../lib", __FILE__)
require "rack/perftools_profiler/version"

Gem::Specification.new do |s|
  s.name        = "rack-perftools_profiler"
  s.version     = Rack::PerftoolsProfiler::VERSION
  s.authors     = ["Ben Brinckerhoff"]
  s.email       = ["ben@bbrinck.com"]
  s.homepage    = "http://github.com/bhb/rack-perftools_profiler"
  s.summary     = %q{Middleware for profiling Rack-compatible apps using perftools.rb}
  s.description = %q{Middleware for profiling Rack-compatible apps using perftools.rb}

  s.rubyforge_project = "rack-perftools_profiler"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency             'perftools.rb', '~> 2.0.0'
  s.add_dependency             'rack',         '~> 1.0'
  s.add_dependency             'open4',        '~> 1.0'
  s.add_development_dependency 'rack',         '~> 1.1'
  s.add_development_dependency 'shoulda',      '~> 2.10'
  s.add_development_dependency 'mocha',        '~> 0.9'
  s.add_development_dependency 'rake',         '~> 0.9.2'

end
