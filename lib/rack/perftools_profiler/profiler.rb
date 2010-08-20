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
    DEFAULT_MODE = :cputime
    UNSET_FREQUENCY = -1

    def initialize(app, options)
      @printer   = (options.delete(:default_printer) { DEFAULT_PRINTER }).to_sym
      ProfileDataAction.check_printer(@printer)
      @frequency = (options.delete(:frequency) { UNSET_FREQUENCY }).to_s
      @mode      = (options.delete(:mode) { DEFAULT_MODE }).to_sym
      raise ProfilerArgumentError, "Invalid option(s): #{options.keys.join(' ')}" unless options.empty?
    end
    
    def profile
      start
      yield
    ensure
      stop
    end

    def self.clear_data
      ::File.delete(PROFILING_DATA_FILE) if ::File.exists?(PROFILING_DATA_FILE)
    end
    
    def start
      set_env_vars
      PerfTools::CpuProfiler.stop
      PerfTools::CpuProfiler.start(PROFILING_DATA_FILE)
      self.profiling = true
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
      if ::File.exists?(PROFILING_DATA_FILE)
        args = "--#{printer}"
        args += " --ignore=#{ignore}" if ignore
        args += " --focus=#{focus}" if focus
        cmd = "pprof.rb #{args} #{PROFILING_DATA_FILE}"
        stdout, stderr, status = run(cmd)
        if(status == 0)
          [printer, stdout]
        else
          raise ProfilingError.new("Running the command '#{cmd}' exited with status #{status}", stderr)
        end
      else
        [:none, nil]
      end
    end

    private

    def run(command)
      out = err = pid = nil
      status = Open4.popen4(command) do |pid, stdin, stdout, stderr|
        stdin.close
        pid = pid
        out = stdout.read
        err = stderr.read
      end
      [out,err,status.exitstatus]
    end

    def set_env_vars
      ENV['CPUPROFILE_REALTIME'] = '1' if @mode == :walltime
      ENV['CPUPROFILE_FREQUENCY'] = @frequency if @frequency != UNSET_FREQUENCY
    end

    def unset_env_vars
      ENV.delete('CPUPROFILE_REALTIME')
      ENV.delete('CPUPROFILE_FREQUENCY')
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

  end

end
