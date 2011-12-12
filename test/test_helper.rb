require 'rubygems'
require 'test/unit'
require 'shoulda'
require 'mocha'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'rack/perftools_profiler'

class Test::Unit::TestCase

  def assert_ok status, body
    unless status == 200
      raise RuntimeError, body
    end
  end

end

ITERATIONS = case RUBY_VERSION
               # Ruby 1.9.x is so fast that we need to add extra iterations
               # to get profiling data
             when /1\.9\../
               350_000
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
