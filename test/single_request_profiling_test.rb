require 'test_helper'

class SingleRequestProfilingTest < Test::Unit::TestCase
  include Rack::PerftoolsProfiler

  def setup
    @app = lambda { |env| ITERATIONS.times {1+2+3+4+5}; [200, {'Content-Type' => 'text/plain'}, ['Oh hai der']] }
    @slow_app = lambda { |env| ITERATIONS.times {1+2+3+4+5}; [200, {'Content-Type' => 'text/plain'}, ['slow app']] }
    @start_env = Rack::MockRequest.env_for('/__start__')
    @stop_env = Rack::MockRequest.env_for('/__stop__')
    @data_env = Rack::MockRequest.env_for('/__data__')
    @root_request_env = Rack::MockRequest.env_for("/")    
    @profiled_request_env = Rack::MockRequest.env_for("/", :params => "profile=true")
    @profiled_request_env_with_times = Rack::MockRequest.env_for("/", :params => "profile=true&times=2")
  end

  context "(common behavior)" do

    should 'default to text printer' do
      _, headers, _ = Rack::PerftoolsProfiler.new(@app).call(@profiled_request_env)
      assert_equal "text/plain", headers['Content-Type']
    end

    should "set CPUPROFILE_REALTIME to 1 if mode is 'walltime'" do
      realtime = ENV['CPUPROFILE_REALTIME']
      assert_nil realtime
      app = lambda do |env|
        realtime = ENV['CPUPROFILE_REALTIME']
        [200, {}, ["hi"]]
      end
      Rack::PerftoolsProfiler.new(app, :mode => 'walltime').call(@profiled_request_env)
      assert_equal '1', realtime
    end

    should "set CPUPROFILE_OBJECTS to 1 if mode is 'objects'" do
      objects = ENV['CPUPROFILE_OBJECTS']
      assert_nil objects
      app = lambda do |env|
        objects = ENV['CPUPROFILE_OBJECTS']
        [200, {}, ["hi"]]
      end
      Rack::PerftoolsProfiler.new(app, :mode => 'objects').call(@profiled_request_env)
      assert_equal '1', objects
    end

    should "not set CPUPROFILE_FREQUENCY by default" do
      frequency = ENV['CPUPROFILE_FREQUENCY']
      assert_nil frequency
      app = lambda do |env|
        frequency = ENV['CPUPROFILE_FREQUENCY']
        [200, {}, ["hi"]]
      end
      Rack::PerftoolsProfiler.new(app).call(@profiled_request_env)
      assert_nil frequency
    end

    should 'alter CPUPROFILE_FREQUENCY if frequency is set' do
      frequency = ENV['CPUPROFILE_FREQUENCY']
      assert_nil frequency
      app = lambda do |env|
        frequency = ENV['CPUPROFILE_FREQUENCY']
        [200, {}, ["hi"]]
      end
      Rack::PerftoolsProfiler.new(app, :frequency => 500).call(@profiled_request_env)
      assert_equal '500', frequency
    end

    should "allow 'printer' param override :default_printer option'" do
      env = Rack::MockRequest.env_for('/', :params => 'profile=true&printer=gif')
      _, headers, _ = Rack::PerftoolsProfiler.new(@app, :default_printer => 'pdf').call(env)
      assert_equal 'image/gif', headers['Content-Type']
    end

    should 'give 400 if printer is invalid' do
      env = Rack::MockRequest.env_for('/', :params => 'profile=true&printer=badprinter')
      status, _, _ = Rack::PerftoolsProfiler.new(@app).call(env)
      assert_equal 400, status
    end

    should "accept 'focus' param" do
      profiled_app = Rack::PerftoolsProfiler.with_profiling_off(TestApp.new, :default_printer => 'text', :mode => 'walltime')
      custom_env = Rack::MockRequest.env_for('/method1', :params => 'profile=true&focus=method1')
      status, headers, body = profiled_app.call(custom_env)
      assert_no_match(/garbage/, RackResponseBody.new(body).to_s)
    end

    should "accept 'ignore' param" do
      profiled_app = Rack::PerftoolsProfiler.with_profiling_off(TestApp.new, :default_printer => 'text', :mode => 'walltime')
      custom_env = Rack::MockRequest.env_for('/method1', :params => 'profile=true&ignore=method1')
      status, headers, body = profiled_app.call(custom_env)
      assert_match(/garbage/, RackResponseBody.new(body).to_s)
      assert_no_match(/method1/, RackResponseBody.new(body).to_s)
    end

  end

  context 'when using the text printer' do

    should 'return profiling data' do
      _, _, body = Rack::PerftoolsProfiler.new(@slow_app, :default_printer => 'text').call(@profiled_request_env)
      assert_match(/Total: \d+ samples/, RackResponseBody.new(body).to_s)
    end

    should 'have Content-Type text/plain' do
      _, headers, _ = Rack::PerftoolsProfiler.new(@app, :default_printer => 'text').call(@profiled_request_env)
      assert_equal "text/plain", headers['Content-Type']
    end
    
    should 'have Content-Length' do
      _, headers, _ = Rack::PerftoolsProfiler.new(@slow_app, :default_printer => 'text').call(@profiled_request_env)
      assert (headers.fetch('Content-Length').to_i > 500)
    end

  end

  context 'when using the gif printer' do

    should 'gif printer has Content-Type image/gif' do
      _, headers, _ = Rack::PerftoolsProfiler.new(@app, :default_printer => 'gif').call(@profiled_request_env)
      assert_equal "image/gif", headers['Content-Type']
    end

    should 'gif printer has Content-Length' do
      _, headers, _ = Rack::PerftoolsProfiler.new(@slow_app, :default_printer => 'gif').call(@profiled_request_env)
      assert headers.fetch('Content-Length').to_i > 25_000
    end

    should 'pdf printer has Content-Type application/pdf' do
      _, headers, _ = Rack::PerftoolsProfiler.new(@app, :default_printer => 'pdf').call(@profiled_request_env)
      assert_equal "application/pdf", headers['Content-Type']
    end

  end
  
  context 'when using the pdf printer' do

    should 'have default filename' do
      _, headers, _ = Rack::PerftoolsProfiler.new(@app, :default_printer => 'pdf').call(@profiled_request_env)
      assert_equal %q{attachment; filename="profile_data.pdf"}, headers['Content-Disposition']
    end

  end

  should 'be able to call app multiple times' do
    env = Rack::MockRequest.env_for('/', :params => 'profile=true&times=3')
    app = @app.clone
    app.expects(:call).times(3)
    Rack::PerftoolsProfiler.new(app, :default_printer => 'text').call(env)
  end

  should 'send Rack environment to underlying application (minus special profiling GET params)' do
    env = Rack::MockRequest.env_for('/', :params => 'profile=true&times=1&param=value&printer=gif&focus=foo&ignore=bar')
    old_env = env.clone
    expected_env = env.clone
    expected_env["QUERY_STRING"] = 'param=value'
    app = @app.clone
    app.expects(:call).with(expected_env)
    Rack::PerftoolsProfiler.new(app, :default_printer => 'gif').call(env)
    assert_equal env, old_env
  end

end
