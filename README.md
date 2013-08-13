# Rack::PerftoolsProfiler

Middleware for profiling Rack-compatible apps using [perftools.rb](http://github.com/tmm1/perftools.rb)

## Quick start

Assuming your application is using Rails 3 (and you have installed the requirements in the next section), add the following code:

Gemfile:

    gem 'rack-perftools_profiler', :require => 'rack/perftools_profiler'

config/application.rb:

    config.middleware.use ::Rack::PerftoolsProfiler, :default_printer => 'gif', :bundler => true

The visit the page you want to profile:

    http://localhost:3000/some_action?profile=true

## Requirements

You'll need graphviz to generate call graphs using dot (for the GIF printer):

    sudo port install graphviz     # OS X
    brew install graphviz          # Homebrew
    sudo apt-get install graphviz  # Debian/Ubuntu

You'll need ps2pdf to generate PDFs (On OS X, ps2pdf comes is installed as part of Ghostscript)

    sudo port install ghostscript  # OSX
    brew install ghostscript       # Homebrew
    sudo apt-get install ps2pdf    # Debian/Ubuntu

## Configuration

Install the gem

    gem install rack-perftools_profiler

Include the middleware

    require 'rack/perftools_profiler'

For Rails 2, add the following to `config/environment.rb`

    config.gem 'rack-perftools_profiler', :lib => 'rack/perftools_profiler'
    require 'rack/perftools_profiler'
    config.middleware.use ::Rack::PerftoolsProfiler, :default_printer => 'gif'

For Rails 3, add the following to your Gemfile

    gem 'rack-perftools_profiler', :require => 'rack/perftools_profiler'

and add the following to config/application.rb

    config.middleware.use ::Rack::PerftoolsProfiler, :default_printer => 'gif', :bundler => true

For Sinatra, call `use` inside a configure block, like so:

    configure do
      use ::Rack::PerftoolsProfiler, :default_printer => 'gif'
    end

For Rack::Builder, call `use` inside the Builder constructor block

    Rack::Builder.new do
      use ::Rack::PerftoolsProfiler, :default_printer => 'gif'
    end

## Options

* `:default_printer` - can be set to 'text', 'gif', or 'pdf'. Default is 'text'.
* `:mode`            - can be set to 'cputime', 'methods', 'objects', 'walltime'. Default is :cputime. See the 'Profiling Modes' section below.
* `:frequency`       - in :cputime mode, the number of times per second the app will be sampled. Default is 100 (times/sec).
* `:bundler`         - run the profiler binary using 'bundle' if set to true. Default is false.
* `:gemfile_dir`     - directory with Gemfile. Default is the current directory.
* `:password`        - password-protect profiling.

## Usage

There are two ways to profile your app: with a single request or with multiple requests.

To profile with a single request, visit the URL you want to profile, but add the `profile` and (optionally) the `times` GET params (which will rerun the action the specified number of times).

Example:

    curl http://localhost:3000/foobar?profile=true&times=3

Note that this will change the status, body, and headers of the response (you'll get
back the profiling data, NOT the original response).

You can also profile your application using multiple requests. When you profile using this method, all responses are normal. You must visit `__stop__`  to complete profiling and then you can view the profiling data by visiting `__data__`.

Example:

    curl http://localhost:3000/__start__
    curl http://localhost:3000/foobar
    curl http://localhost:3000/foobaz
    curl http://localhost:3000/__stop__
    curl http://localhost:3000/__data__

## Profiling Data Options

Regardless of how you profile your application, you can add additional params to change how the
data is displayed. When using a single request, these params are just added to the URL being profiled.
When using multiple requests, they are added to the `__data__` URL.

* printer - overrides the default_printer option (see above)
* ignore  - a regular expression of the area of code to ignore
* focus   - a regular expression of the area of code to solely focus on.

(for 'ignore' and 'focus', please see http://google-perftools.googlecode.com/svn/trunk/doc/cpuprofile.html#pprof
for more details)

## Profiling Modes

perftools.rb (and therefore, the Rack middleware) can be put into three different profiling modes.

* CPU time mode            - Reports how many CPU cycles are spent in each section of code. This is the default and can be enabled by setting `:mode => :cputime`
* Method call mode         - Report how many method calls are made inside each method. Enable by setting `:mode => :methods`
* Object allocation mode   - Reports the percentage of object allocations performed in each section of code. Enable by setting `:mode => :objects`
* Wall time mode           - Reports the amount of time (as in, wall clock time) spent in each section of code. Enable by setting `:mode => :walltime`

For example, consider the following Sinatra application:

    require 'sinatra'
    require 'rack/perftools_profiler'

    configure do
      use ::Rack::PerftoolsProfiler, :default_printer => 'gif', :mode => :cputime
    end

    get "/slow" do
      sleep(3)
      "hello"
    end

In the default mode, there will be no profiling data for the 'slow' route, because it uses few CPU cycles (You'll see the message 'No nodes to print').

If you change the mode to `:walltime`, you'll get profiling data, since the call to `sleep` causes the code to spend several seconds of wall time in the block.

## Overriding the Profiling mode

You can also switch the profiling mode on a per-request basis, but ONLY if you are switching to 'methods' or 'objects' mode. Due to the implementation of perftools.rb, it is NOT possible to switch to 'walltime' or 'cputime' modes.

To switch to another mode, provide the 'mode' option. When profiling with a single request, add the option to the URL profiled:

    curl http://localhost:3000/foobar?profile=true&mode=objects

When profiling using multiple requests, add the option when visiting `__start__` :

    curl http://localhost:3000/__start__?mode=objects

If the 'mode' option is omitted, the middleware will default to the mode specified at configuration.

## Profiling in production

It is recommended that you always profile your application in the 'production' environment (using `rails server -e production` or an equivalent), since there can be important differences between 'development' and 'production' that may affect performance.

However, it is recommended that you profile your application on a development or staging machine rather than on a production machine. This is because profiling with multiple requests *will not* work if your app is running in multiple Ruby server processes.

Profiling a single request will work if there are multiple server processes. If your staging machine is publicly accessible, you can password-protect single-request profiling by using the `:password` option and then using the `profile` GET parameter to provide the password:

    curl http://localhost:3000/foobar?profile=PASSWORD

## Changing behavior with environment variables

The mode and frequency settings are enabled by setting environment variables. Some of these environment variables must be set before 'perftools' is required. If you only require 'rack/perftools_profiler', it will do the right thing (require 'perftools' after setting the environment variables).

If you need to require 'perftools' before 'rack/perftools_profiler' (or you have other problems changing the mode or frequency), try using these environment variables yourself.

Setting the frequency:

    CPUPROFILE_FREQUENCY=500 ruby your_app.rb

Setting the mode to 'wall time'

    CPUPROFILE_REALTIME=1 ruby your_app.rb

Setting the mode to 'object allocation'

    CPUPROFILE_OBJECTS=1 ruby your_app.rb

## Acknowledgments

A huge thanks to Aman Gupta for the awesome perftools.rb gem.

The basic idea and initial implementation of the middleware was heavily influenced by Rack::Profiler from rack-contrib.

## Note on Patches/Pull Requests

* Fork the project.
* Make your feature addition or bug fix.
* Add tests for it. This is important so I don't break it in a
  future version unintentionally.
* Commit, do not mess with rakefile, version, or history.
  (if you want to have your own version, that is fine but bump version in a commit by itself I can ignore when I pull)
* Send me a pull request. Bonus points for topic branches.

## Copyright

Copyright (c) 2010-2011 Ben Brinckerhoff. See LICENSE for details.
