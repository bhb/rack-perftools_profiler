module Rack::PerftoolsProfiler

  class StopProfiling < Action
    
    def act
      @profiler.stop
    end

    def response
      [200, {'Content-Type' => 'text/plain'}, 
       [<<-EOS
Profiling is now disabled.
Visit /__data__ to view the results.
EOS
       ]]
    end

  end  

end
