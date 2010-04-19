require 'test_helper'

ITERATIONS = case RUBY_VERSION
             when /1\.9\.1/ 
               350_000   # Ruby 1.9.1 is that we need to add extra iterations to get profiling data
             else 
               35_000
             end

# From the Rack spec (http://rack.rubyforge.org/doc/files/SPEC.html) :
# The Body must respond to each and must only yield String values. The Body should not be an instance of String.
# ... The Body commonly is an Array of Strings, the application instance itself, or a File-like object. 

class RackResponseBody
  include Test::Unit::Assertions

  def initialize(body)
    assert !body.instance_of?(String)
    @body = body
  end

  def to_s
    str = ""
    @body.each do |part|
      str << part
    end
    str
  end

end

class TestApp

  def call(env)
    case env['PATH_INFO']
    when /method1/
      ITERATIONS.times do
        self.class.new.method1
      end
      GC.start
    when /method2/
      ITERATIONS.times do 
        self.class.new.method2
      end
      GC.start
    end
    [200, {}, ['Done']]
  end

  def method1
    100.times do 
      1+2+3+4+5
    end
  end

  def method2
    100.times do
      1+2+3+4+5
    end
  end

end

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

      should 'pass all Lint checks with text printer' do
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

    context 'without profiling' do

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

    context 'simple profiling mode' do
      
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

      context 'text printer' do

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

      context 'gif printer' do

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
      
      context 'pdf printer' do

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

    context 'start/stop profiling' do

      should "set CPUPROFILE_REALTIME to 1 if mode is 'walltime' " do
        realtime = ENV['CPUPROFILE_REALTIME']
        assert_nil realtime
        app = lambda do |env|
          realtime = ENV['CPUPROFILE_REALTIME']
          [200, {}, ["hi"]]
        end
        profiled_app = Rack::PerftoolsProfiler.new(app, :mode => 'walltime')
        profiled_app.call(@start_env)
        profiled_app.call(@root_request_env)
        profiled_app.call(@stop_env)
        assert_equal '1', realtime
      end

      should 'alter CPUPROFILE_FREQUENCY if frequency is set' do
        frequency = ENV['CPUPROFILE_FREQUENCY']
        assert_nil frequency
        app = lambda do |env|
          frequency = ENV['CPUPROFILE_FREQUENCY']
          [200, {}, ["hi"]]
        end
        profiled_app = Rack::PerftoolsProfiler.new(app, :frequency => 250)
        profiled_app.call(@start_env)
        profiled_app.call(@root_request_env)
        assert_equal '250', frequency
      end

      context 'when profiling is on' do

        should 'not provide profiling data when __data__ is called' do
          Rack::PerftoolsProfiler.clear_data
          profiled_app = Rack::PerftoolsProfiler.with_profiling_off(@app, :default_printer => 'text')
          profiled_app.call(@start_env)
          profiled_app.call(@root_request_env)
          status, _, body = profiled_app.call(@data_env)
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
          assert_equal env, old_env
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
          assert_equal env, old_env
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
          profiled_app.call(@start_env)
          profiled_app.call(@root_request_env)
          profiled_app.call(@stop_env)
          status, headers, body = profiled_app.call(@data_env)
          assert_equal 200, status
          assert_equal "image/gif", headers['Content-Type']
        end

      end
      
      should 'keeps data from multiple calls' do
        profiled_app = Rack::PerftoolsProfiler.with_profiling_off(TestApp.new, :default_printer => 'text', :mode => 'walltime')
        profiled_app.call(@start_env)
        profiled_app.call(Rack::MockRequest.env_for('/method1'))
        profiled_app.call(Rack::MockRequest.env_for('/method2'))
        profiled_app.call(@stop_env)
        status, headers, body = profiled_app.call(@data_env)
        assert_match(/method1/, RackResponseBody.new(body).to_s)
        assert_match(/method2/, RackResponseBody.new(body).to_s)
      end

      should "allow 'printer' param to override :default_printer option'" do
        profiled_app = Rack::PerftoolsProfiler.new(@app, :default_printer => 'pdf')
        profiled_app.call(@start_env)
        profiled_app.call(@root_request_env)
        profiled_app.call(@stop_env)
        custom_data_env = Rack::MockRequest.env_for('__data__', :params => 'printer=gif')
        _, headers, _ = profiled_app.call(custom_data_env)
        assert_equal 'image/gif', headers['Content-Type']
      end

      should "accept 'focus' param" do
        profiled_app = Rack::PerftoolsProfiler.with_profiling_off(TestApp.new, :default_printer => 'text', :mode => 'walltime')
        profiled_app.call(@start_env)
        profiled_app.call(Rack::MockRequest.env_for('/method1'))
        profiled_app.call(Rack::MockRequest.env_for('/method2'))
        profiled_app.call(@stop_env)
        custom_data_env = Rack::MockRequest.env_for('__data__', :params => 'focus=method1')
        status, headers, body = profiled_app.call(custom_data_env)
        assert_no_match(/method2/, RackResponseBody.new(body).to_s)
      end

      should "accept 'ignore' param" do
        profiled_app = Rack::PerftoolsProfiler.with_profiling_off(TestApp.new, :default_printer => 'text', :mode => 'walltime')
        profiled_app.call(@start_env)
        profiled_app.call(Rack::MockRequest.env_for('/method1'))
        profiled_app.call(Rack::MockRequest.env_for('/method2'))
        profiled_app.call(@stop_env)
        custom_data_env = Rack::MockRequest.env_for('__data__', :params => 'ignore=method1')
        status, headers, body = profiled_app.call(custom_data_env)
        assert_no_match(/method1/, RackResponseBody.new(body).to_s)
      end

    end
  end

end
