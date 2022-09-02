require 'minitest/autorun'
require 'sqlite3'
require_relative '../lib/datastore'
require 'json'

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


DB_FILE = "graph_test.db"

def sqlite_query dbfile, query 
    begin
        db = SQLite3::Database.open(DB_FILE)
        db.results_as_hash = true
        return db.execute(query)
    rescue Exception => e
        puts e
    ensure
        db.close if db
    end
    return nil
end

class NodeTest < MiniTest::Test
    def simplenode
        assert_equal(nil, Node.new().id)
        assert_equal(1, Node.from_json(APPLE).id)
    end
end

class DatastoreTest < Minitest::Test
    @@setup_complete = false
    @@tests_run = 0
    @db = nil
    def setup(db_file: "graph_test.db")
        @db_file = db_file
        @@tests_run+=1
        @db = Datastore.new(db_file: @db_file, debug: false)
        if(!@@setup_complete)
            @@setup_complete = true
        end
    end
    def teardown
        File.delete @db_file
        # if @@tests_run == DatastoreTest.runnable_methods.length 
        #     File.delete @db_file
        #     puts "ran #{@@tests_run} tests for #{self.class}"
        # end
    end
    def test_sqldbfile
        skip
        assert_path_exists(@db_file)# File.stat(@db_file).writable? 
    end
    
    def test_initialize
        skip
        assert_equal(0, sqlite_query(@db_file, 'SELECT * from nodes').count)
        [APPLE, WOZ, JOBS, WAYNE, MARKKULA].each_with_index {|nodestr,idx| @db.add_node(nodestr, idx+1)}
        assert_equal(5, sqlite_query(@db_file, 'SELECT * from nodes').count)

        assert_equal(0, sqlite_query(@db_file, 'SELECT * from edges').count)
        EDGES.each {|edge|
            @db.connect_nodes(edge[0],edge[1],edge[2])
        }
        assert_equal(6, sqlite_query(@db_file, 'SELECT * from edges').count)
    end

    def test_initialize_crud
        skip
        #add_node
        assert_equal(0, sqlite_query(@db_file, 'SELECT * from nodes').count)
        @db.add_node(APPLE, 1)
        results = sqlite_query(@db_file, 'SELECT * from nodes where id = "1"')
        assert_equal(1, results.count, "added 1 node expected 1 in return")
        assert_equal("Apple Computer Company", JSON.parse(results[0]["body"])["name"], "got this as results #{results}")

        @db.add_node(WOZ, 2)
        results = sqlite_query(@db_file, 'SELECT * from nodes')
        assert_equal(2, results.count, "added 1 node expected 2 in return")
        res = JSON.parse(results[1]["body"])
        assert_equal("2", res["id"], "id should be 2")
        assert_equal("Steve Wozniak", res["name"], "name does not match")

        @db.add_node(JOBS, 3)
        results = sqlite_query(@db_file, 'SELECT * from nodes')
        assert_equal(3, results.count, "added 1 node expected 3 in return")

        @db.add_node(WAYNE, 4)
        results = sqlite_query(@db_file, 'SELECT * from nodes')
        assert_equal(4, results.count, "added 1 node expected 4 in return")

        @db.add_node(MARKKULA, 5)
        results = sqlite_query(@db_file, 'SELECT * from nodes')
        assert_equal(5, results.count, "added 1 node expected 5 in return")
        results = JSON.parse(results[4]["body"])
        assert_equal("5", results["id"], "id should be 5")
        assert_equal("Mike Markkula", results["name"], "name does not match")

        assert_raises(Exception, "this should have raised exception") {  @db.add_node(APPLE) }
        
        #find_node
        results = @db.find_node(3)
        # puts results
        assert_equal("Steve Jobs", results.body["name"])


        #find_node
        results = @db.find_node(6)
        assert_equal({}, results)

        #upsert node
        @db.upsert_node(APPLE, 1)
        results = @db.find_node(1)
        assert_equal(results.body,JSON.parse(APPLE))

        # puts @db.find_node(2)
        @db.upsert_node(WOZ_NICK, 2)
        results = @db.find_node(2)
        assert_equal(results.body, JSON.parse(WOZ_NICK))

        #find_nodes
        results = @db.find_nodes({'name': 'Steve'}, :search_cond_like, :search_val_starts)
        assert_equal(results.count, 2)
        assert_equal(results[0], Node.from_json(WOZ_NICK))
        assert_equal(results[1], Node.from_json(JOBS))

        results = @db.find_nodes({'name': 'Jobs'}, :search_cond_like, :search_val_contains)
        assert_equal(results.count, 1)
        assert_equal(results[0], Node.from_json(JOBS))

        results = @db.find_nodes({'type': 'founder'}, :search_cond_like, :search_val_contains)
        assert_equal(results.count, 3)
        assert_equal(results[2].body["name"], Node.from_json(WAYNE).body["name"])

        results = @db.find_nodes({'type': 'investor'}, :search_cond_like, :search_val_contains)
        assert_equal(results.count, 1)
        assert_equal(results[0].body["name"], Node.from_json(MARKKULA).body["name"])

        results = @db.find_nodes()
        assert_equal(results.count, 5)

        #delete node
        results = @db.find_node(5)
        assert_equal(results.body["name"], Node.from_json(MARKKULA).body["name"])
        @db.remove_node(5)
        results = @db.find_node(5)
        assert_equal({}, results)
        @db.add_node(MARKKULA, 5)
        results = @db.find_node(5)
        assert_equal(results.body["name"], Node.from_json(MARKKULA).body["name"])
        assert_equal(0, sqlite_query(@db_file, 'SELECT * from edges').count)

        EDGES.each {|edge|
            @db.connect_nodes(edge[0],edge[1],edge[2])
        }
        assert_equal(6, sqlite_query(@db_file, 'SELECT * from edges').count)
        @db.remove_node(5)
        assert_equal(5, sqlite_query(@db_file, 'SELECT * from edges').count)

        @db.remove_node(1)
        assert_equal(3, sqlite_query(@db_file, 'SELECT * from nodes').count)
        assert_equal(1, sqlite_query(@db_file, 'SELECT * from edges').count)
    end

    def test_bulk
        skip
        bodies = []
        nodes = []
        counter = 0
        [APPLE, WOZ, JOBS, WAYNE, MARKKULA].each {|nodestr|
            counter += 1
            body = _set_id(counter, _from_json(nodestr))
            bodies.append(_to_json(body))
            nodes.append(counter)
        }
        #puts bodies
        find_results = @db.find_nodes()
        assert_equal(find_results.count, 0)
        results = @db.add_nodes(bodies, nodes)
        find_results = @db.find_nodes()
        assert_equal(find_results.count, 5)
        
        results = @db.upsert_nodes(bodies, nodes)
        results = @db.find_nodes()
        assert_equal(find_results, results)

        assert_equal(0, sqlite_query(@db_file, 'SELECT * from edges').count)
        tp_edges = EDGES.transpose
        results = @db.connect_many_nodes(tp_edges[0],tp_edges[1],tp_edges[2])
        assert_equal(6, sqlite_query(@db_file, 'SELECT * from edges').count)

        results = @db.remove_nodes(nodes)
        assert_equal(0, @db.find_nodes().count)
        assert_equal(0, sqlite_query(@db_file, 'SELECT * from edges').count)

    end

    # test traversal and finding
    def test_traversal
        assert_equal(0, sqlite_query(@db_file, 'SELECT * from nodes').count)
        # [APPLE, WOZ, JOBS, WAYNE, MARKKULA].each_with_index {|nodestr,idx| @db.add_node(nodestr, idx+1)}
        [APPLE, WOZ, JOBS, WAYNE, MARKKULA].each_with_index {|nodestr,idx| new_add_node(@db_file, nodestr, idx+1)}
        assert_equal(5, sqlite_query(@db_file, 'SELECT * from nodes').count)

        # assert_equal(0, sqlite_query(@db_file, 'SELECT * from edges').count)
        # EDGES.each {|edge|
        #     @db.connect_nodes(edge[0],edge[1],edge[2])
        # }
        # assert_equal(6, sqlite_query(@db_file, 'SELECT * from edges').count)

        # assert_equal(@db.traverse(2, 3), [2, 1, 3])

    end


#     # def test_flunk
#     #     flunk "You shall not pass"
#     # end
end
