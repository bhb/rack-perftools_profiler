module Rack::PerftoolsProfiler

  class ProfilingError < RuntimeError

    attr_reader :stderr

    def initialize(message, stderr)
      super(message)
      @stderr = stderr
    end

  end

  class Profiler

    def self.tmpdir
      dir = nil
      Dir.chdir Dir.tmpdir do dir = Dir.pwd end # HACK FOR OSX
      dir
    end

    PROFILING_DATA_FILE = ::File.join(self.tmpdir, 'rack_perftools_profiler.prof')
    PROFILING_SETTINGS_FILE = ::File.join(self.tmpdir, 'rack_perftools_profiler.config')
    DEFAULT_PRINTER = :text
    MODES = [:cputime, :methods, :objects, :walltime]
    DEFAULT_MODE = :cputime
    CHANGEABLE_MODES = [:methods, :objects]
    UNSET_FREQUENCY = "-1"
    DEFAULT_GEMFILE_DIR = '.'

    def initialize(app, options)
      @printer     = (options.delete(:default_printer) { DEFAULT_PRINTER }).to_sym
      @frequency   = (options.delete(:frequency) { UNSET_FREQUENCY }).to_s
      @mode        = (options.delete(:mode) { DEFAULT_MODE }).to_sym
      @bundler     = options.delete(:bundler) { false }
      @gemfile_dir = options.delete(:gemfile_dir) { DEFAULT_GEMFILE_DIR }
      @password    = options.delete(:password) { nil }
      @mode_for_request = nil
      ProfileDataAction.check_printer(@printer)
      ensure_mode_is_valid(@mode)
      # We need to set the enviroment variables before loading perftools
      set_env_vars
      require 'perftools'
      raise ProfilerArgumentError, "Invalid option(s): #{options.keys.join(' ')}" unless options.empty?
    end
    
    def profile(mode = nil)
      start(mode)
      yield
    ensure
      stop
    end

    def self.clear_data
      ::File.delete(PROFILING_DATA_FILE) if ::File.exists?(PROFILING_DATA_FILE)
    end

    def password_valid?(password)
      @password.nil? || password == @password
    end

    def should_check_password?
      ! @password.nil?
    end

    def start(mode = nil)
      ensure_mode_is_changeable(mode) if mode
      PerfTools::CpuProfiler.stop
      if (mode)
        @mode_for_request = mode
      end  
      unset_env_vars
      set_env_vars
      PerfTools::CpuProfiler.start(PROFILING_DATA_FILE)
      self.profiling = true
    ensure
      @mode_for_request = nil
    end

    def stop
      PerfTools::CpuProfiler.stop
      self.profiling = false
      unset_env_vars
    end

    def profiling?
      pstore_transaction(true) do |store|
        store[:profiling?]
      end
    end

    def data(options = {})
      printer = (options.fetch('printer') {@printer}).to_sym
      ignore = options.fetch('ignore') { nil }
      focus = options.fetch('focus') { nil }
      nodecount = options.fetch('nodecount') { nil }
      nodefraction = options.fetch('nodefraction') { nil }
      if ::File.exists?(PROFILING_DATA_FILE)
        args = ["--#{printer}"]
        args << "--ignore=#{ignore}" if ignore
        args << "--focus=#{focus}" if focus
        args << "--nodecount=#{nodecount}" if nodecount
        args << "--nodefraction=#{nodefraction}" if nodefraction
        args << PROFILING_DATA_FILE
        cmd = ["pprof.rb"] + args
        cmd = ["bundle", "exec"] + cmd if @bundler

        stdout, stderr, status = Dir.chdir(@gemfile_dir) { run(*cmd) }
        if status!=0
          raise ProfilingError.new("Running the command '#{cmd.join(" ")}' exited with status #{status}", stderr)
        elsif stdout.length == 0 && stderr.length > 0
          raise ProfilingError.new("Running the command '#{cmd.join(" ")}' failed to generate a file", stderr)
        else
          [printer, stdout]
        end
      else
        [:none, nil]
      end
    end

    private

    def run(*command)
      out = err = ""
      pid = nil
      status = Open4.popen4(*command) do |pid, stdin, stdout, stderr|
        stdin.close
        pid = pid
        out = stdout.read
        err = stderr.read
      end
      [out,err,status.exitstatus]
    end

    def set_env_vars
      if @mode_for_request
        mode_to_use = @mode_for_request
      else
        mode_to_use = @mode
      end
      ENV['CPUPROFILE_REALTIME'] = '1' if mode_to_use == :walltime
      ENV['CPUPROFILE_OBJECTS'] = '1' if mode_to_use == :objects
      ENV['CPUPROFILE_METHODS'] = '1' if mode_to_use == :methods
      ENV['CPUPROFILE_FREQUENCY'] = @frequency if @frequency != UNSET_FREQUENCY
    end

    def unset_env_vars
      ENV.delete('CPUPROFILE_REALTIME')
      ENV.delete('CPUPROFILE_FREQUENCY')
      ENV.delete('CPUPROFILE_OBJECTS')
      ENV.delete('CPUPROFILE_METHODS')
    end
    
    def profiling=(value)
      pstore_transaction(false) do |store|
        store[:profiling?] = value
      end
    end

    def pstore_transaction(read_only)
      pstore = PStore.new(PROFILING_SETTINGS_FILE)
      pstore.transaction(read_only) do
        yield pstore if block_given?
      end
    end

    def ensure_mode_is_changeable(mode)
      if !CHANGEABLE_MODES.include?(mode)
        message = "Cannot change mode to '#{mode}'.\n"
        mode_string = CHANGEABLE_MODES.map{|m| "'#{m}'"}.join(", ")
        message += "Per-request mode changes are only available for the following modes: #{mode_string}.\n"
        message += "See the README for more details."
        raise ProfilerArgumentError, message
      end
    end

    def ensure_mode_is_valid(mode)
      if !MODES.include?(mode)
        message = "Invalid mode: #{mode}.\n"
        message += "Valid modes are: #{MODES.join(', ')}"
        raise ProfilerArgumentError, message
      end
    end

  end

end
