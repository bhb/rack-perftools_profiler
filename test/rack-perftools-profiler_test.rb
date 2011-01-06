require 'test_helper'

class RackPerftoolsProfilerTest < Test::Unit::TestCase
  include Rack::PerftoolsProfiler

  context "testing Rack::PerftoolsProfiler" do

    setup do
      @app = lambda { |env| ITERATIONS.times {1+2+3+4+5}; [200, {'Content-Type' => 'text/plain'}, ['Oh hai der']] }
      @slow_app = lambda { |env| ITERATIONS.times {1+2+3+4+5}; [200, {'Content-Type' => 'text/plain'}, ['slow app']] }
      @start_env = Rack::MockRequest.env_for('/__start__')
      @stop_env = Rack::MockRequest.env_for('/__stop__')
      @data_env = Rack::MockRequest.env_for('/__data__')
      @root_request_env = Rack::MockRequest.env_for("/")    
      @profiled_request_env = Rack::MockRequest.env_for("/", :params => "profile=true")
      @profiled_request_env_with_times = Rack::MockRequest.env_for("/", :params => "profile=true&times=2")
    end

    context 'Rack::Lint checks' do

      should 'pass all Lint checks with text printer' do
        app = Rack::Lint.new(Rack::PerftoolsProfiler.with_profiling_off(@slow_app, :default_printer => 'text'))
        app.call(@root_request_env)
        app.call(@profiled_request_env)
        app.call(@profiled_request_env_with_times)
        app.call(@start_env)
        app.call(@stop_env)
        app.call(@data_env)
      end

      should 'pass all Lint checks with gif printer' do
        app = Rack::Lint.new(Rack::PerftoolsProfiler.with_profiling_off(@slow_app, :default_printer => 'gif'))
        app.call(@root_request_env)
        app.call(@profiled_request_env)
        app.call(@profiled_request_env_with_times)
        app.call(@start_env)
        app.call(@stop_env)
        app.call(@data_env)
      end

    end

    should 'raise error if options contains invalid key' do
      error = assert_raises ProfilerArgumentError do 
        Rack::PerftoolsProfiler.with_profiling_off(@app, :mode => 'walltime', :default_printer => 'gif', :foobar => 'baz')
      end
      assert_match(/Invalid option\(s\)\: foobar/, error.message)
    end
    
    should 'raise error if printer is invalid' do
      error = assert_raises ProfilerArgumentError do 
        Rack::PerftoolsProfiler.with_profiling_off(@app, :mode => 'walltime', :default_printer => 'badprinter')
      end
      assert_match(/Invalid printer type\: badprinter/, error.message)
    end
    
    should 'not modify options hash' do
      options = {:mode => 'walltime', :default_printer => 'gif'}
      old_options = options.clone
      Rack::PerftoolsProfiler.with_profiling_off(@app, options)
      assert_equal old_options, options
    end

    context 'when not profiling' do

      should 'call app directly' do
        status, headers, body = Rack::PerftoolsProfiler.with_profiling_off(@app).call(@root_request_env)
        assert_equal 200, status
        assert_equal 'text/plain', headers['Content-Type']
        assert_equal 'Oh hai der', RackResponseBody.new(body).to_s
      end
      
      should 'provide no data by default when __data__ is called' do
        Rack::PerftoolsProfiler.clear_data
        status, headers, body = Rack::PerftoolsProfiler.with_profiling_off(@app, :default_printer => 'text').call(@data_env)
        assert_equal 404, status
        assert_equal 'text/plain', headers['Content-Type']
        assert_match(/No profiling data available./, RackResponseBody.new(body).to_s)
      end

    end

    context "when in bundler mode" do
      
      should "call pprof.rb using 'bundle' command if bundler is set" do
        status = stub_everything(:exitstatus => 0)
        profiled_app = Rack::PerftoolsProfiler.new(@app, :bundler => true)
        Open4.expects(:popen4).with(regexp_matches(/^bundle exec pprof\.rb/)).returns(status)
        profiled_app.call(@profiled_request_env)
      end

      should "change directory into the current directory if custom Gemfile dir is not provided" do
        profiled_app = Rack::PerftoolsProfiler.new(@app, :bundler => true, :gemfile_dir => 'bundler')
        Dir.expects(:chdir).with('bundler').returns(["","",0])
        profiled_app.call(@profiled_request_env)
      end

      should "change directory into custom Gemfile dir if provided" do
        profiled_app = Rack::PerftoolsProfiler.new(@app, :bundler => true)
        Dir.expects(:chdir).with('.').returns(["","",0])
        profiled_app.call(@profiled_request_env)
      end
    
    end

    context "when changing mode for single request" do

      should "default to configured mode if mode is empty string" do
        realtime = ENV['CPUPROFILE_REALTIME']
        assert_nil realtime
        app = lambda do |env|
          realtime = ENV['CPUPROFILE_REALTIME']
          [200, {}, ["hi"]]
        end
        request = Rack::MockRequest.env_for("/", :params => 'profile=true&mode=')
        Rack::PerftoolsProfiler.new(app, :mode => :walltime).call(request)
        assert_equal '1', realtime
      end

      should "set CPUPROFILE_OBJECTS to 1 if mode is 'objects'" do
        objects = ENV['CPUPROFILE_OBJECTS']
        assert_nil objects
        app = lambda do |env|
          objects = ENV['CPUPROFILE_OBJECTS']
          [200, {}, ["hi"]]
        end
        request = Rack::MockRequest.env_for("/", :params => 'profile=true&mode=objects')
        Rack::PerftoolsProfiler.new(app, :mode => :cputime).call(request)
        assert_equal '1', objects
      end

      should "return to default mode if no mode is specified" do
        objects = ENV['CPUPROFILE_OBJECTS']
        assert_nil objects
        app = lambda do |env|
          objects = ENV['CPUPROFILE_OBJECTS']
          [200, {}, ["hi"]]
        end
        
        request = Rack::MockRequest.env_for("/", :params => 'profile=true&mode=objects')
        rack_profiler = Rack::PerftoolsProfiler.new(app, :mode => :cputime)
        rack_profiler.call(request)
        rack_profiler.call(@profiled_request_env)
        assert_nil objects
      end

      should "return error message if mode is unrecognized" do
        profiled_app = Rack::PerftoolsProfiler.new(@app)
        mode = "foobar"
        request = Rack::MockRequest.env_for("/", :params => "profile=true&mode=#{mode}")
        status, _, body = profiled_app.call(request)
        assert_equal 400, status
        assert_match(/Cannot change mode to '#{mode}'.\nPer-request mode changes are only available for the following modes: 'objects'/, 
                     RackResponseBody.new(body).to_s)
      end

      should "return error message if mode is 'walltime'" do
        profiled_app = Rack::PerftoolsProfiler.new(@app)
        mode = "walltime"
        request = Rack::MockRequest.env_for("/", :params => "profile=true&mode=#{mode}")
        status, _, body = profiled_app.call(request)
        assert_equal 400, status
        assert_match(/Cannot change mode to '#{mode}'.\nPer-request mode changes are only available for the following modes: 'objects'/, 
                     RackResponseBody.new(body).to_s)        
      end

      should "return error message if mode is 'cputime'" do
        profiled_app = Rack::PerftoolsProfiler.new(@app)
        mode = "cputime"
        request = Rack::MockRequest.env_for("/", :params => "profile=true&mode=#{mode}")
        status, _, body = profiled_app.call(request)
        assert_equal 400, status
        assert_match(/Cannot change mode to '#{mode}'.\nPer-request mode changes are only available for the following modes: 'objects'/, 
                     RackResponseBody.new(body).to_s)        
      end

    end

  end

end
