module Rack::PerftoolsProfiler

  class StartProfiling < Action
    include Rack::PerftoolsProfiler::Utils

    def initialize(*args)
      super
      request = Rack::Request.new(@env)
      @mode = let(request.GET['mode']) do |m|
        if m.nil? || m.empty?
          nil
        else
          m.to_sym
        end
      end
    end
    
    def act
      @profiler.start(@mode)
    end

    def response
      [200, {'Content-Type' => 'text/plain'}, 
       [<<-EOS
Profiling is now enabled.
Visit the URLS that should be profiled.
When you are finished, visit /__stop__, then visit /__data__ to view the results.
EOS
       ]]
    end

  end

end
