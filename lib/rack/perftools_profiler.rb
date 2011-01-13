require 'rack'
require 'pstore'
require 'open4'

require 'rack/perftools_profiler/utils'
require 'rack/perftools_profiler/profiler_middleware'
require 'rack/perftools_profiler/action'
require 'rack/perftools_profiler/profiler'
require 'rack/perftools_profiler/start_profiling'
require 'rack/perftools_profiler/stop_profiling'
require 'rack/perftools_profiler/profile_data_action'
require 'rack/perftools_profiler/profile_once'
require 'rack/perftools_profiler/return_data'
require 'rack/perftools_profiler/call_app_directly'

module Rack::PerftoolsProfiler

  def self.new(app, options={})
    ProfilerMiddleware.new(app, options)
  end

  # helpers for testing
  def self.clear_data
    Profiler.clear_data
  end

  def self.with_profiling_off(app, options = {})
    clear_data
    instance = ProfilerMiddleware.new(app, options)
    instance.force_stop
    instance
  end

end
