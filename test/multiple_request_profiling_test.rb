require 'test_helper'

class MultipleRequestProfilingTest < Test::Unit::TestCase
  include Rack::PerftoolsProfiler

  def setup
    @app = lambda { |env| ITERATIONS.times {1+2+3+4+5}; [200, {'Content-Type' => 'text/plain'}, ['Oh hai der']] }
    @start_env = Rack::MockRequest.env_for('/__start__')
    @stop_env = Rack::MockRequest.env_for('/__stop__')
    @data_env = Rack::MockRequest.env_for('/__data__')
    @root_request_env = Rack::MockRequest.env_for("/")
  end

  def profile(profiled_app, options = {})
    start = options.fetch(:start) { @start_env }
    stop = options.fetch(:stop) { @stop_env }
    data = options.fetch(:data) { @data_env }

    profiled_app.call(start) if start != :none
    if block_given?
      yield profiled_app
    else
      profiled_app.call(@root_request_env)
    end
    last_response = profiled_app.call(stop) if stop != :none
    if data!=nil && data!=:none
      last_response = profiled_app.call(data) if data
    end
    last_response
  end

  def profile_requests(profiled_app, requests, options = {})
    get_data = options.fetch(:get_data) { true }
    if requests == :default
      requests = [@root_request_env]
    else
      requests = Array(requests)
    end
    profiled_app.call(@start_env)
    requests.each do |request|
      profiled_app.call(request)
    end
    profiled_app.call(@stop_env)
    profiled_app.call(@data_env) if get_data
  end

  context "(common behavior)" do

    should 'default to text printer' do
      # TODO - It's weird that this passes if you pass in :data => :none to #profile
      _, headers, _ = profile(Rack::PerftoolsProfiler.new(@app))
      assert_equal "text/plain", headers['Content-Type']
    end

    should "set CPUPROFILE_REALTIME to 1 if mode is 'walltime' " do
      realtime = ENV['CPUPROFILE_REALTIME']
      assert_nil realtime
      app = lambda do |env|
        realtime = ENV['CPUPROFILE_REALTIME']
        [200, {}, ["hi"]]
      end
      profiled_app = Rack::PerftoolsProfiler.new(app, :mode => 'walltime')
      profile(profiled_app, :data => :none)
      assert_equal '1', realtime
    end

    should "set CPUPROFILE_OBJECTS to 1 if mode is 'objects'" do
      objects = ENV['CPUPROFILE_OBJECTS']
      assert_nil objects
      app = lambda do |env|
        objects = ENV['CPUPROFILE_OBJECTS']
        [200, {}, ["hi"]]
      end
      profiled_app = Rack::PerftoolsProfiler.new(app, :mode => 'objects')
      profile(profiled_app, :data => :none)
      assert_equal '1', objects
    end

    should "set CPUPROFILE_METHODS to 1 if mode is 'methods'" do
      methods = ENV['CPUPROFILE_METHODS']
      assert_nil methods
      app = lambda do |env|
        methods = ENV['CPUPROFILE_METHODS']
        [200, {}, ["hi"]]
      end
      profiled_app = Rack::PerftoolsProfiler.new(app, :mode => 'methods')
      profile(profiled_app, :data => :none)
      assert_equal '1', methods
    end

    should "not set CPUPROFILE_FREQUENCY by default" do
      frequency = ENV['CPUPROFILE_FREQUENCY']
      assert_nil frequency
      frequency = '1'
      app = lambda do |env|
        frequency = ENV['CPUPROFILE_FREQUENCY']
        [200, {}, ["hi"]]
      end
      profiled_app = Rack::PerftoolsProfiler.new(app)
      profile(profiled_app, :data => :none)
      assert_nil frequency
    end

    should 'alter CPUPROFILE_FREQUENCY if frequency is set' do
      frequency = ENV['CPUPROFILE_FREQUENCY']
      assert_nil frequency
      app = lambda do |env|
        frequency = ENV['CPUPROFILE_FREQUENCY']
        [200, {}, ["hi"]]
      end
      profiled_app = Rack::PerftoolsProfiler.new(app, :frequency => 250)
      profile(profiled_app, :data => :none)
      assert_equal '250', frequency
    end

    should "allow 'printer' param to override :default_printer option'" do
      profiled_app = Rack::PerftoolsProfiler.new(@app, :default_printer => 'pdf')
      custom_data_env = Rack::MockRequest.env_for('__data__', :params => 'printer=gif')
      status, headers, body = profile(profiled_app, :data => custom_data_env)
      assert_ok status, body
      assert_equal 'image/gif', headers['Content-Type']
    end

    should 'give 400 if printer is invalid' do
      profiled_app = Rack::PerftoolsProfiler.new(@app, :default_printer => 'pdf')
      custom_data_env = Rack::MockRequest.env_for('__data__', :params => 'printer=badprinter')
      status, _, body = profile(profiled_app, :data => custom_data_env)
      assert_equal 400, status
      assert_match /Invalid printer type/, body.join
    end

    should "accept 'focus' param" do
      profiled_app = Rack::PerftoolsProfiler.with_profiling_off(TestApp.new, :default_printer => 'text', :mode => 'walltime')
      custom_data_env = Rack::MockRequest.env_for('__data__', :params => 'focus=method1')

      status, headers, body = profile(profiled_app, :data => custom_data_env) do |app|
        app.call(Rack::MockRequest.env_for('/method1'))
        app.call(Rack::MockRequest.env_for('/method2'))
      end
      assert_match(/method1/,    RackResponseBody.new(body).to_s)
      assert_no_match(/method2/, RackResponseBody.new(body).to_s)
    end

    should "accept 'ignore' param" do
      profiled_app = Rack::PerftoolsProfiler.with_profiling_off(TestApp.new, :default_printer => 'text', :mode => 'walltime')
      custom_data_env = Rack::MockRequest.env_for('__data__', :params => 'ignore=method1')

      status, headers, body = profile(profiled_app, :data => custom_data_env) do |app|
        app.call(Rack::MockRequest.env_for('/method1'))
        app.call(Rack::MockRequest.env_for('/method2'))
      end

      assert_match(/method2/,    RackResponseBody.new(body).to_s)
      assert_no_match(/method1/, RackResponseBody.new(body).to_s)
    end

    context "when in bundler mode" do

      should "call pprof.rb using 'bundle' command if bundler is set" do
        status = stub_everything(:exitstatus => 0)
        profiled_app = Rack::PerftoolsProfiler.new(@app, :bundler => true)
        Open4.expects(:popen4).with('bundle', 'exec', 'pprof.rb', '--text', regexp_matches(/rack_perftools_profiler\.prof$/)).returns(status)
        profile(profiled_app)
      end

      should "change directory into the current directory if custom Gemfile dir is not provided" do
        profiled_app = Rack::PerftoolsProfiler.new(@app, :bundler => true, :gemfile_dir => 'bundler')
        Dir.expects(:chdir).with('bundler').returns(["","",0])
        profile(profiled_app)
      end

      should "change directory into custom Gemfile dir if provided" do
        profiled_app = Rack::PerftoolsProfiler.new(@app, :bundler => true)
        Dir.expects(:chdir).with('.').returns(["","",0])
        profile(profiled_app)
      end

    end

    context "when the nodefraction parameter is specified" do
      should "call pprof.rb with nodefraction" do
        status = stub_everything(:exitstatus => 0)
        profiled_app = Rack::PerftoolsProfiler.new(@app)
        custom_env = Rack::MockRequest.env_for('/method1', :params => 'profile=true&nodefraction=160')
        Open4.expects(:popen4).with('pprof.rb', '--text',  '--nodefraction=160', regexp_matches(/rack_perftools_profiler\.prof$/)).returns(status)
        profiled_app.call(custom_env)
      end
    end


    context "when overriding profiling mode" do

      should "default to configured mode if mode is empty string" do
        realtime = ENV['CPUPROFILE_REALTIME']
        assert_nil realtime
        app = lambda do |env|
          realtime = ENV['CPUPROFILE_REALTIME']
          [200, {}, ["hi"]]
        end
        profiled_app = Rack::PerftoolsProfiler.new(app, :mode => :walltime)
        modified_start_env = Rack::MockRequest.env_for('/__start__', :params => 'mode=')
        profile(profiled_app, :start => modified_start_env, :data => :none)
        assert_equal '1', realtime
      end

      should "set CPUPROFILE_OBJECTS to 1 if mode is 'objects'" do
        objects = ENV['CPUPROFILE_OBJECTS']
        assert_nil objects
        app = lambda do |env|
          objects = ENV['CPUPROFILE_OBJECTS']
          [200, {}, ["hi"]]
        end
        profiled_app = Rack::PerftoolsProfiler.new(app, :mode => :cputime)
        modified_start_env = Rack::MockRequest.env_for('/__start__', :params => 'mode=objects')
        profile(profiled_app, :start => modified_start_env, :data => :none)
        assert_equal '1', objects
      end

      should "set CPUPROFILE_METHODS to 1 if mode is 'methods'" do
        methods = ENV['CPUPROFILE_METHODS']
        assert_nil methods
        app = lambda do |env|
          methods = ENV['CPUPROFILE_METHODS']
          [200, {}, ["hi"]]
        end
        profiled_app = Rack::PerftoolsProfiler.new(app, :mode => :cputime)
        modified_start_env = Rack::MockRequest.env_for('/__start__', :params => 'mode=methods')
        profile(profiled_app, :start => modified_start_env, :data => :none)
        assert_equal '1', methods
      end

      should "return to default mode if no mode is specified" do
        objects = ENV['CPUPROFILE_OBJECTS']
        assert_nil objects
        app = lambda do |env|
          objects = ENV['CPUPROFILE_OBJECTS']
          [200, {}, ["hi"]]
        end

        profiled_app = Rack::PerftoolsProfiler.new(app, :mode => :cputime)
        modified_start_env = Rack::MockRequest.env_for('/__start__', :params => 'mode=objects')
        profile(profiled_app, :start => modified_start_env, :data => :none)

        assert_equal '1', objects

        profile(profiled_app, :data => :none)

        assert_nil objects
      end

      should "return error message if mode is unrecognized" do
        profiled_app = Rack::PerftoolsProfiler.new(@app)
        mode = "foobar"

        modified_start_env = Rack::MockRequest.env_for('/__start__', :params => "mode=#{mode}")

        status, _, body = profiled_app.call(modified_start_env)

        assert_equal 400, status
        assert_match(/Cannot change mode to '#{mode}'.\nPer-request mode changes are only available for the following modes: 'methods', 'objects'/,
                     RackResponseBody.new(body).to_s)
      end

      should "return error message if mode is 'walltime'" do
        profiled_app = Rack::PerftoolsProfiler.new(@app)
        mode = "walltime"

        modified_start_env = Rack::MockRequest.env_for('/__start__', :params => "mode=#{mode}")

        status, _, body = profiled_app.call(modified_start_env)

        assert_equal 400, status
        assert_match(/Cannot change mode to '#{mode}'.\nPer-request mode changes are only available for the following modes: 'methods', 'objects'/,
                     RackResponseBody.new(body).to_s)
      end

      should "return error message if mode is 'cputime'" do
        profiled_app = Rack::PerftoolsProfiler.new(@app)
        mode = "cputime"

        modified_start_env = Rack::MockRequest.env_for('/__start__', :params => "mode=#{mode}")

        status, _, body = profiled_app.call(modified_start_env)

        assert_equal 400, status
        assert_match(/Cannot change mode to '#{mode}'.\nPer-request mode changes are only available for the following modes: 'methods', 'objects'/,
                     RackResponseBody.new(body).to_s)
      end

    end

  end

  context 'when profiling is enabled' do

    should 'not provide profiling data when __data__ is called' do
      Rack::PerftoolsProfiler.clear_data
      profiled_app = Rack::PerftoolsProfiler.with_profiling_off(@app, :default_printer => 'text')
      status, _ , body = profile(profiled_app, :stop => :none)
      assert_equal 400, status
      assert_match(/No profiling data available./, RackResponseBody.new(body).to_s)
    end

    should 'pass on profiling params in environment' do
      env = Rack::MockRequest.env_for('/', :params => 'times=2')
      old_env = env.clone
      app = @app.clone
      expected_env = env.clone
      expected_env['rack.request.query_string'] = 'times=2'
      expected_env['rack.request.query_hash'] = {'times' => '2'}
      app.expects(:call).with(expected_env)
      profiled_app = Rack::PerftoolsProfiler.new(app, :default_printer => 'text')
      profiled_app.call(@start_env)
      profiled_app.call(env)
      # I used to clone the environment to avoid conflicts, but this seems to break
      # Devise/Warden.
      # assert_equal env, old_env
    end

    should 'pass on non-profiling params in environment' do
      env = Rack::MockRequest.env_for('/', :params => 'param=value')
      old_env = env.clone
      app = @app.clone
      expected_env = env.clone
      expected_env['rack.request.query_string'] = 'param=value'
      expected_env['rack.request.query_hash'] = {'param' => 'value'}
      app.expects(:call).with(expected_env)
      profiled_app = Rack::PerftoolsProfiler.new(app, :default_printer => 'text')
      profiled_app.call(@start_env)
      profiled_app.call(env)
      # I used to clone the environment to avoid conflicts, but this seems to break
      # Devise/Warden.
      # assert_equal env, old_env
    end

    should 'not alter regular calls' do
      profiled_app = Rack::PerftoolsProfiler.with_profiling_off(@app, :default_printer => 'gif')
      profiled_app.call(@start_env)
      status, headers, body = profiled_app.call(@root_request_env)
      assert_equal 200, status
      assert_equal 'text/plain', headers['Content-Type']
      assert_equal 'Oh hai der', RackResponseBody.new(body).to_s
    end

  end

  context 'after profiling is finished' do

    should 'return profiling data when __data__ is called' do
      profiled_app = Rack::PerftoolsProfiler.with_profiling_off(@app, :default_printer => 'gif')
      status, headers, body = profile(profiled_app)
      assert_equal 200, status
      assert_equal "image/gif", headers['Content-Type']
    end

  end

  should 'keeps data from multiple calls' do
    profiled_app = Rack::PerftoolsProfiler.with_profiling_off(TestApp.new, :default_printer => 'text', :mode => 'walltime')
    status, headers, body = profile(profiled_app) do |app|
      app.call(Rack::MockRequest.env_for('/method1'))
      app.call(Rack::MockRequest.env_for('/method2'))
    end
    assert_match(/method1/, RackResponseBody.new(body).to_s)
    assert_match(/method2/, RackResponseBody.new(body).to_s)
  end

  context "when a profile password is required" do

    should "call app directly on normal calls if password not provided" do
      profiled_app = Rack::PerftoolsProfiler.with_profiling_off(@app, :password => 'secret')
      profiled_app.call(@start_env)
      status, headers, body = profiled_app.call(@root_request_env)
      assert_equal 200, status
      assert_equal 'text/plain', headers['Content-Type']
      assert_equal 'Oh hai der', RackResponseBody.new(body).to_s
    end

    should "call __start__ if password is provided" do
      profiled_app = Rack::PerftoolsProfiler.new(@app, :password => "secret")
      actual_password = "secret"
      start_env = Rack::MockRequest.env_for('/__start__', :params => "profile=#{actual_password}")
      status, _, body = profiled_app.call(start_env)
      assert_equal 200, status
      assert_match(/Profiling is now enabled/, RackResponseBody.new(body).to_s)
    end

    should "call __stop__ if password is provided" do
      profiled_app = Rack::PerftoolsProfiler.new(@app, :password => "secret")
      actual_password = "secret"
      stop_env = Rack::MockRequest.env_for('/__stop__', :params => "profile=#{actual_password}")
      status, _, body = profiled_app.call(stop_env)
      assert_equal 200, status
      assert_match(/Profiling is now disabled/, RackResponseBody.new(body).to_s)
    end

    should "call __data__ if password is provided" do
      profiled_app = Rack::PerftoolsProfiler.new(@app, :password => "secret")
      actual_password = "secret"
      start_env = Rack::MockRequest.env_for('/__start__', :params => "profile=#{actual_password}")
      stop_env = Rack::MockRequest.env_for('/__stop__', :params => "profile=#{actual_password}")
      data_env = Rack::MockRequest.env_for('/__data__', :params => "profile=#{actual_password}")
      profiled_app.call(start_env)
      profiled_app.call(@root_request_env)
      profiled_app.call(stop_env)
      status, _, body = profiled_app.call(data_env)
      assert_equal 200, status
      assert_match(/Total: \d+ samples/, RackResponseBody.new(body).to_s)
    end

    should "error on __start__ if password does not match" do
      profiled_app = Rack::PerftoolsProfiler.new(@app, :password => "secret")
      actual_password = "foobar"
      start_env = Rack::MockRequest.env_for('/__start__', :params => "profile=#{actual_password}")
      status, _, body = profiled_app.call(start_env)
      assert_equal 401, status
      assert_match(/Profiling is password-protected/, RackResponseBody.new(body).to_s)
    end

    should "error on __stop__ if password does not match" do
      profiled_app = Rack::PerftoolsProfiler.new(@app, :password => "secret")
      actual_password = "foobar"
      stop_env = Rack::MockRequest.env_for('/__stop__', :params => "profile={actual_password}")
      status, _, body = profiled_app.call(stop_env)
      assert_equal 401, status
      assert_match(/Profiling is password-protected/, RackResponseBody.new(body).to_s)
    end

    should "error on __data__ if password does not match" do
      profiled_app = Rack::PerftoolsProfiler.new(@app, :password => "secret")
      actual_password = "foobar"
      data_env = Rack::MockRequest.env_for('/__data__', :params => "profile={actual_password}")
      status, _, body = profiled_app.call(data_env)
      assert_equal 401, status
      assert_match(/Profiling is password-protected/, RackResponseBody.new(body).to_s)
    end

    should "error on __start__ if password is missing" do
      profiled_app = Rack::PerftoolsProfiler.new(@app, :password => "secret")
      actual_password = "foobar"
      start_env = Rack::MockRequest.env_for('/__start__')
      status, _, body = profiled_app.call(start_env)
      assert_equal 401, status
      assert_match(/Profiling is password-protected/, RackResponseBody.new(body).to_s)
    end

    should "error on __stop__ if password is missing" do
      profiled_app = Rack::PerftoolsProfiler.new(@app, :password => "secret")
      actual_password = "foobar"
      stop_env = Rack::MockRequest.env_for('/__stop__')
      status, _, body = profiled_app.call(stop_env)
      assert_equal 401, status
      assert_match(/Profiling is password-protected/, RackResponseBody.new(body).to_s)
    end

    should "error on __data__ if password is missing" do
      profiled_app = Rack::PerftoolsProfiler.new(@app, :password => "secret")
      actual_password = "foobar"
      data_env = Rack::MockRequest.env_for('/__data__')
      status, _, body = profiled_app.call(data_env)
      assert_equal 401, status
      assert_match(/Profiling is password-protected/, RackResponseBody.new(body).to_s)
    end

  end

end
