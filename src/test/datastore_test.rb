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
class DatastoreTest < Minitest::Test
    def setup
        @db_file = "graph_test.db"
        @db = Datastore.new(@db_file)
    end
    def teardown
        File.delete @db_file
    end
    def test_sqldbfile
        assert_path_exists(@db_file)# File.stat(@db_file).writable? 
    end
    
    def test_addNode
        @db.add_node(APPLE,id: 1)
        results = sqlite_query(@db_file, 'SELECT * from nodes where id = "1"')
        assert_equal 1, results.count, "added 1 node expected 1 in return"
        assert_equal "Apple Computer Company", JSON.parse(results[0]["body"])["name"], "got this as results #{results}"

        @db.add_node(WOZ, id:2)
        results = sqlite_query(@db_file, 'SELECT * from nodes')
        assert_equal 2, results.count, "added 1 node expected 2 in return"
        res = JSON.parse(results[1]["body"])
        assert_equal "2", res["id"], "id should be 2"
        assert_equal "Steve Wozniak", res["name"], "name does not match"

        @db.add_node(JOBS,id: 3)
        results = sqlite_query(@db_file, 'SELECT * from nodes')
        assert_equal 3, results.count, "added 1 node expected 3 in return"

        @db.add_node(WAYNE, id: 4)
        results = sqlite_query(@db_file, 'SELECT * from nodes')
        assert_equal 4, results.count, "added 1 node expected 4 in return"

        @db.add_node(MARKKULA,id: 5)
        results = sqlite_query(@db_file, 'SELECT * from nodes')
        assert_equal 5, results.count, "added 1 node expected 5 in return"
        res = JSON.parse(results[4]["body"])
        assert_equal "5", res["id"], "id should be 5"
        assert_equal "Mike Markkula", res["name"], "name does not match"

        assert_raises(Exception, "this should have raised exception") {  @db.add_node(APPLE) }
        
    end
    # def test_flunk
    #     flunk "You shall not pass"
    # end
end
