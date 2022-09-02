require 'minitest/autorun'
require 'sqlite3'
require_relative '../lib/graphstore'

APPLE       = '{"name":"Apple Computer Company","type":["company","start-up"],"founded":"April 1, 1976","id":"1"}'
WOZ         = '{"id":"2","name":"Steve Wozniak","type":["person","engineer","founder"]}'
JOBS        = '{"id":"3","name":"Steve Jobs","type":["person","designer","founder"]}'
WAYNE       = '{"name":"Ronald Wayne","type":["person","administrator","founder"]}'
MARKKULA    = '{"name":"Mike Markkula","type":["person","investor"]}'
WOZ_NICK    = '{"name":"Steve Wozniak","type":["person","engineer","founder"],"nickname":"Woz","id":"2"}'
FOUNDED     = '{"action":"founded"}'
INVESTED    = '{"action":"invested","equity":80000,"debt":170000}'
DIVESTED    = '{"action":"divested","amount":800,"date":"April 12, 1976"}'

EDGES = [[1, 4, DIVESTED],
        [2, 1, FOUNDED],
        [2, 3, '{}'],
        [3, 1, FOUNDED],
        [4, 1, FOUNDED],
        [5, 1, INVESTED]]

DBFILE = "graph_test.db"

# local test query only used in first test
def sqlite_query dbfile, query 
    begin
        db = SQLite3::Database.open(DBFILE)
        db.results_as_hash = true
        return db.execute(query)
    rescue Exception => e
        puts e
    ensure
        db.close if db
    end
    return nil
end
class GraphStoreTest < Minitest::Test
    @@setup_complete = false
    @@tests_run = 0
    def setup(dbfile=DBFILE)
        @dbfile = dbfile
        @@tests_run+=1
        @debug = false
        GraphStore.initialize(dbfile, debug:false)
        if(!@@setup_complete) 
            @@setup_complete = true 
        end
    end
    def teardown
        File.delete @dbfile
    end
    def test_sqldbfile
        assert_path_exists(@dbfile)# File.stat(@db_file).writable? 
    end
    
    def test_initialize
        assert_equal(0, sqlite_query(@dbfile, 'SELECT * from nodes').count)
        [APPLE, WOZ, JOBS, WAYNE, MARKKULA].each_with_index {|nodestr,idx|
            GraphStore.add_node(@dbfile, nodestr, idx+1, debug:@debug)
        }
        assert_equal(5, sqlite_query(@dbfile, 'SELECT * from nodes').count)

        assert_equal(0, sqlite_query(@dbfile, 'SELECT * from edges').count)
        EDGES.each {|edge|
            puts "\nsource: #{edge[0]}, target:#{edge[1]}, props:#{edge[2]}}"
            GraphStore.connect_nodes(edge[0],edge[1],edge[2])
        }
        # assert_equal(6, sqlite_query(@dbfile, 'SELECT * from edges').count)
    end
end