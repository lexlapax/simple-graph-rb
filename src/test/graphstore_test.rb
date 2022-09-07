require 'minitest/autorun'
require 'sqlite3'
require_relative '../lib/graphstore'
# require_relative 

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
        assert_path_exists(@dbfile)
    end
    
    def test_initialize
        assert_equal(0, sqlite_query(@dbfile, 'SELECT * from nodes').count)
        [APPLE, WOZ, JOBS, WAYNE, MARKKULA].each_with_index {|nodestr,idx|
            GraphStore.add_node(@dbfile, nodestr, idx+1, debug:@debug)
        }
        assert_equal(5, sqlite_query(@dbfile, 'SELECT * from nodes').count)

        assert_equal(0, sqlite_query(@dbfile, 'SELECT * from edges').count)
        EDGES.each {|edge|
            GraphStore.connect_nodes(@dbfile, edge[0],edge[1],edge[2])
        }
        assert_equal(6, sqlite_query(@dbfile, 'SELECT * from edges').count)
    end

    def test_find_add_remove
        assert_equal({}, GraphStore.find_node(@dbfile, 1))
        GraphStore.add_node(@dbfile, APPLE, 1)
        GraphStore.add_node(@dbfile, WOZ, 2)
        GraphStore.add_node(@dbfile, JOBS, 3)
        GraphStore.add_node(@dbfile, WAYNE, 4)
        GraphStore.add_node(@dbfile, MARKKULA, 5)
        assert_equal(parse_json(APPLE), GraphStore.find_node(@dbfile, 1))
        assert_equal(parse_json(WOZ), GraphStore.find_node(@dbfile, 2))
        assert_equal(parse_json(JOBS), GraphStore.find_node(@dbfile, 3))
        assert_equal(parse_json(WAYNE)["name"], GraphStore.find_node(@dbfile, 4)["name"])
        assert_equal(parse_json(MARKKULA)["name"], GraphStore.find_node(@dbfile, 5)["name"])


        assert_raises(Exception, "this should have raised exception") {  GraphStore.add_node(@dbfile, APPLE, 1) }
        assert_equal({}, GraphStore.find_node(@dbfile, 6))

        #upsert node
        GraphStore.upsert_node(@dbfile, APPLE, 1)
        assert_equal(parse_json(APPLE), GraphStore.find_node(@dbfile, 1))
        # # puts @db.find_node(2)
        GraphStore.upsert_node(@dbfile, WOZ_NICK, 2)
        assert_equal(parse_json(WOZ_NICK), GraphStore.find_node(@dbfile, 2))

        #find_nodes
        results = GraphStore.find_nodes(@dbfile, {'name': 'Steve'}, :search_cond_like, :search_val_starts)
        assert_equal(results.count, 2)
        assert_equal(parse_json(WOZ_NICK), results[0])
        assert_equal(parse_json(JOBS), results[1])

        results =GraphStore.find_nodes(@dbfile, {'name': 'Jobs'}, :search_cond_like, :search_val_contains)
        assert_equal(results.count, 1)
        assert_equal(parse_json(JOBS), results[0])

        results =GraphStore.find_nodes(@dbfile, {'type': 'founder'}, :search_cond_like, :search_val_contains)
        assert_equal(results.count, 3)
        assert_equal(results[2]["name"], parse_json(WAYNE)["name"])

        results =GraphStore.find_nodes(@dbfile, {'type': 'investor'}, :search_cond_like, :search_val_contains)
        assert_equal(results.count, 1)
        assert_equal(results[0]["name"], parse_json(MARKKULA)["name"])

        results =GraphStore.find_nodes(@dbfile)
        assert_equal(results.count, 5)

        EDGES.each {|edge|
            GraphStore.connect_nodes(@dbfile, edge[0],edge[1],edge[2])
        }
        assert_equal(6, sqlite_query(@dbfile, 'SELECT * from edges').count)
        GraphStore.remove_node(@dbfile, 5)
        assert_equal(5, sqlite_query(@dbfile, 'SELECT * from edges').count)
        assert_equal(4, sqlite_query(@dbfile, 'SELECT * from nodes').count)

        GraphStore.remove_node(@dbfile, 1)
        assert_equal(1, sqlite_query(@dbfile, 'SELECT * from edges').count)
        assert_equal(3, sqlite_query(@dbfile, 'SELECT * from nodes').count)
    end


    def test_bulk
        bodies = []
        node_ids = []
        counter = 0
        [APPLE, WOZ, JOBS, WAYNE, MARKKULA].each {|nodestr|
            counter += 1
            body = GraphStore._set_id(counter, parse_json(nodestr))
            bodies.append(body)
            node_ids.append(counter)
        }
        #puts bodies
        find_results = GraphStore.find_nodes(@dbfile)
        assert_equal(0, find_results.count)
        results = GraphStore.add_nodes(@dbfile, bodies, node_ids)
        find_results = GraphStore.find_nodes(@dbfile)
        assert_equal(5, find_results.count)
  
        GraphStore.upsert_nodes(@dbfile, bodies, node_ids)
        results = GraphStore.find_nodes(@dbfile)
        assert_equal(find_results, results)

        # assert_equal(0, sqlite_query(@dbfile, 'SELECT * from edges').count)
        # tp_edges = EDGES.transpose
        # results = @db.connect_many_nodes(tp_edges[0],tp_edges[1],tp_edges[2])
        # assert_equal(6, sqlite_query(@dbile, 'SELECT * from edges').count)

        # results = @db.remove_nodes(node_ids)
        # assert_equal(0, GrpahStore.find_nodes(@dbfile, ).count)
        # assert_equal(0, sqlite_query(@dbile, 'SELECT * from edges').count)

    end
end