module Rack::PerftoolsProfiler

  class ReturnPasswordError < Action
    include Rack::PerftoolsProfiler::Utils

    def response
      [401, 
       {'Content-Type' => 'text/plain'}, 
       ["Profiling is password-protected. Password is incorrect.\nProvide a password using the 'profile' GET param:\nhttp://domain.com/foobar?profile=PASSWORD"]]
    end

  end

end
