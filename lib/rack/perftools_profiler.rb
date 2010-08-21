# REQUIREMENTS
#
# You'll need graphviz to generate call graphs using dot (for the GIF printer):
#
#    sudo port install graphviz     # osx
#    sudo apt-get install graphviz  # debian/ubuntu

# You'll need ps2pdf to generate PDFs 
# On OS X, ps2pdf comes is installed as part of Ghostscript
# 
#    sudo port install ghostscript # osx
#    brew install ghostscript      # homebrew
#    sudo apt-get install ps2pdf   # debian/ubuntu

# CONFIGURATION
# 
# Include the middleware
#
#     require 'rack/perftools_profiler'
#
# For Rails, add the following to config/environment.rb
# 
#    config.middleware.use Rack::PerftoolsProfiler, :default_printer => 'gif'
#
# For Sinatra, call 'use' inside a configure block, like so:
#
#     configure :profiling do
#       use Rack::PerftoolsProfiler, :default_printer => 'gif'
#     end
#
# For Rack::Builder, call 'use' inside the Builder constructor block
#
#     Rack::Builder.new do
#       use Rack::PerftoolsProfiler, :default_printer => 'gif'
#     end
#       
#
# OPTIONS
#
# :bundler         - run profiler binary from bundle if set to true
# :gemfile_dir     - directory with Gemfile
# :default_printer - can be set to 'text', 'gif', or 'pdf'. Default is :text
# :mode            - can be set to 'cputime' or 'walltime'. Default is :cputime
# :frequency       - in :cputime mode, the number of times per second the app will be sampled.
#                    Default is 100 (times/sec)
#
# USAGE 
#
# There are two modes for the profiler
# 
# First, you can run in 'simple' mode. Just visit the url you want to profile, but
# add the 'profile' and (optionally) the 'times' GET params
# 
# example: 
# curl http://localhost:8080/foobar?profile=true&times=3
#
# Note that this will change the status, body, and headers of the response (you'll get
# back the profiling data, NOT the original response.
#
#
# The other mode is start/stop mode.
# 
# example:
# curl http://localhost:8080/__start__
# curl http://localhost:8080/foobar
# curl http://localhost:8080/foobaz
# curl http://localhost:8080/__stop__
# curl http://localhost:8080/__data__
#
# In this mode, all responses are normal. You must visit __stop__ to complete profiling and
# then you can view the profiling data by visiting __data__

# PROFILING DATA OPTIONS
#
# In both simple and start/stop modes, you can add additional params to change how the data
# is displayed. In simple mode, these params are just added to the URL being profiled. In
# start/stop mode, they are added to the __data__ URL

# printer - overrides the default_printer option (see above)
# ignore  - a regular expression of the area of code to ignore 
# focus   - a regular expression of the area of code to solely focus on.

# (for ignore and focus, please see http://google-perftools.googlecode.com/svn/trunk/doc/cpuprofile.html#pprof
# for more details)
#
# ACKNOWLEDGMENTS
# 
# The basic idea and initial implementation was heavily influenced by Rack::Profiler from rack-contrib.

require 'rack'
require 'perftools'
require 'pstore'
require 'open4'

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
    instance = ProfilerMiddleware.new(app, options)
    instance.force_stop
    instance
  end

end
