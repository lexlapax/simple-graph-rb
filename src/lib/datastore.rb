require 'sqlite3'
require 'json'
require_relative 'const'

class Datastore
    attr_accessor :db_file
    def initialize(db_file= "graph.db")
        @db_file = db_file
        return atomic(@db_file,GRAPH_SCHEMA,batch: true)
    end

    def _set_id(id, data)
        data["id"] = id.to_s if !data.key?("id")
        return data
    end
    
    def atomic(db_file, statement, data: nil, batch: false)
        db = nil
        ret = nil
        begin
            db = SQLite3::Database.open(db_file)
            db.execute("PRAGMA foreign_keys = TRUE;")
            if batch
                ret = db.execute_batch(statement, data)
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

    def add_node(body, id: nil)
        if body.class == String
            data = JSON.parse(body)
        else
            data = body
        end
        return atomic(@db_file, INSERT_NODE, data: JSON.dump(_set_id(id, data)))
    end

end