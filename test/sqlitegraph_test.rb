require 'minitest/autorun'
require_relative '../lib/sqlitegraph'

class DBTest < Minitest::Test 
    def test_world
        assert_equal 'world', Hello.world, "Hello.world should return a string called 'world'"
    end
    
    def test_flunk
        flunk "You shall not pass"
    end
end

class NodeTest < Minitest::Test 
end

class EdgeTest < Minitest::Test 

end
