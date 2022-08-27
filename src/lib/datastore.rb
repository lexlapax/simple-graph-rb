require 'sqlite3'
require 'json'
require_relative 'const'

class Datastore
    attr_accessor :db_file

    def initialize(db_file= "graph.db")
        @db_file = db_file
        @test_counter = 0
        return atomic(@db_file,GRAPH_SCHEMA,batch: true)
    end

    def _set_id(id, data)
        data["id"] = id.to_s if !data.key?("id")
        return data
    end
    
    def Node
        attr_accessor :id, :body
        def initialize(id: nil, body: {})
            @id = id
            @body = body
        end
        def self.from_json(str)
            return Node.new(JSON.parse(str))
        end

        def to_s
            return "node=id:#{@id},body:{#{@body}}"
        end
    end

    def Edge 
        attr_accessor :source, :target, :label
        def initialize(source: Node.new, target: Node.new, label: "points_to")
            @source = source
            @target = target
            @label = label
        end
    end
    def atomic(db_file, statement, data: nil, batch: false)
        db = nil
        ret = nil
        begin
            db = SQLite3::Database.open(db_file)
            db.results_as_hash = true
            db.execute("PRAGMA foreign_keys = TRUE;")
            if batch
                db.execute_batch(statement, data)
                return []
            else
                ret = db.execute(statement, data)
            end
        rescue => err
            puts err
            raise err
        ensure
            db.close if db
        end
        return ret
    end

    def _from_json(object)
        return object if object.class != String
        return JSON.parse(object)
    end

    def _to_json(object)
        return object if object.class == String
        return JSON.dump(object)
    end
    
    def add_node(body, id)
        data = _from_json(body)
        return atomic(@db_file, INSERT_NODE, data: _to_json(_set_id(id, data)))
    end

    def find_node(id)
        result = atomic(@db_file, SEARCH_NODE_ID, data: id.to_s)
        if result == nil or result.empty?
            return {}
        else 
            return _from_json(result[0]["body"])
        end
    end

    def upsert_node(body, id)
        node = find_node(id)
        if node == nil or node.empty?
            return add_node(body, id)
        else
            data = _from_json(body)
            data.delete("id")

            ret = atomic(@db_file, UPDATE_NODE, data: _to_json(node.merge(data)))
        end

    end
end