module Rack::PerftoolsProfiler

  class StartProfiling < Action

    def act
      @profiler.start
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
