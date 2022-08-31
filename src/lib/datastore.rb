require 'sqlite3'
require 'json'
require_relative 'const'


def _from_json(object)
    return object if object.class != String
    return JSON.parse(object)
end

def _to_json(object)
    return object if object.class == String
    return JSON.dump(object)
end

def _set_id(id, data)
    data["id"] = id.to_s if !data.key?("id")
    return data
end

#generic functions for generating sql "=", like statements
def search_cond_equals(props, predicate="=")
    props.map{|key, value|
        "json_extract(body, '$.#{key}') #{predicate} ?"
    }.join(" AND ")
end
def search_cond_like(props)
    return search_cond_equals(props, 'LIKE')
end
def search_val_equals(props)
    return props.values
end
def search_val_starts(props)
    return props.values.collect {|val| "#{val}%" }
end
def search_val_contains(props)
    return props.values.collect {|val| "%#{val}%" }
end    

class Datastore
    attr_accessor :db_file

    def initialize(db_file: "graph.db", debug: false)
        @db_file = db_file
        @test_counter = 0
        @debug = debug
        return atomic(@db_file,GRAPH_SCHEMA,batch: true)
    end

    def atomic(db_file, statement, bind_vars: [], batch: false)
        db = nil
        ret = nil
        @test_counter += 1
        #@debug = debug
        # puts "counter: #{@test_counter}, #{statement}, #{bind_vars}"
        begin
            db = SQLite3::Database.open(db_file)
            if @debug
                db.trace {|sqltrace|
                    puts "#{@test_counter}: #{sqltrace}"
                }
            end
            db.results_as_hash = true
            db.execute("PRAGMA foreign_keys = TRUE;")
            if batch
                db.execute_batch(statement)
            else
                ret = db.execute(statement, bind_vars)
            end
        rescue => err
            puts err
            raise err
        ensure
            db.close if db
        end
        # ret.each {|arr| 
        #     puts arr
        # } if ret
        return ret
    end

    def find_node(id)
        result = atomic(@db_file, SEARCH_NODE_ID, bind_vars: [id.to_s])
        if result == nil or result.empty?
            return {}
        else 
            return Node.new(_from_json(result[0]["body"]), id)
        end
    end
 
    def find_nodes(props={}, where_fn=:search_cond_equals, search_fn=:search_val_equals)
        if props == nil or props == {} 
            return atomic(@db_file, SEARCH_NODE.chomp(" WHERE "))
        else
            return atomic(@db_file, SEARCH_NODE + send(where_fn, props), bind_vars: send(search_fn, props)).map { |row|
                Node.from_json(row["body"])
            }
        end

        #return result#.map {|nodestr| Node.from_json(nodestr["body"])}
    end

    def add_node(body, id)
        data = _from_json(body)
        return atomic(@db_file, INSERT_NODE, bind_vars: [_to_json(_set_id(id, data))])
    end

    def upsert_node(body, id)
        node = find_node(id)

        if node == nil or node.empty? or node == {}
            ret =  add_node(body, id)
        else
            data = _from_json(body)
            data.delete("id")
            ret = atomic(@db_file, UPDATE_NODE, bind_vars: [_to_json(node.body.merge(data)),id])
        end
    end

    def _add_nodes_prep_sql(bodies)
        sqls = bodies.map { |bodystr|
            sqlstr = INSERT_NODE.sub(/\?/, "'#{bodystr}'") 
        }.join(";\n")
        sqls += ";"
        return sqls
    end
    def add_nodes(bodies, ids)
        #_add_nodes_prep_sql(bodies)
        return atomic(@db_file, _add_nodes_prep_sql(bodies), batch: true)
    end

    def upsert_nodes(bodies, ids)
        for i in 0..ids.length-1
            upsert_node(bodies[i],ids[i])
        end
        return nil
    end

    def connect_nodes(source_id, target_id, props={})
        return atomic(@db_file, INSERT_EDGE, bind_vars: [source_id, target_id, _to_json(props)])
    end

    def _connect_many_nodes_prep_sql(sources, targets, props)
        sqls = ""
        [sources, targets, props].transpose.each {|src, tgt, label|
            sqls = sqls+ INSERT_EDGE.sub(/\?/, "#{src}").sub(/\?/,"#{tgt}").sub(/\?/,"'#{_to_json(label)}'")+";\n"
        }
        return sqls
    end
    
    def connect_many_nodes(sources, targets, props)
        return atomic(@db_file, _connect_many_nodes_prep_sql(sources, targets, props), batch: true)
    end

    def remove_node(id)
        atomic(@db_file, DELETE_EDGE_SQL, bind_vars: [id, id])
        atomic(@db_file, DELETE_NODE, bind_vars: [id])
    end

    def _remove_many_prep_sql(ids)
        sql_edge = ""
        sql_node = ""
        ids.each {|id|
            sql_edge = sql_edge + DELETE_EDGE_SQL.sub(/\?/,"#{id}").sub(/\?/,"#{id}") + ";\n"
            sql_node = sql_node + DELETE_NODE.sub(/\?/,"#{id}") +";\n"
        }
        return sql_edge + sql_node
    end
    

    def remove_nodes(ids)
        return atomic(@db_file, _remove_many_prep_sql(ids), batch: true)
    end
end

class Node
    attr_accessor :id, :body
    def initialize(body={},id=nil)
        @id = id
        @body = body
        if @id==nil && @body.has_key?("id")
            @id = @body["id"]
        end
    end
    def self.from_json(str, id=nil)
        return Node.new(_from_json(str), id)
    end

    def ==(obj)
        return false if !obj.class.eql?(self.class)
        return false if !obj.id.eql?(self.id)
        return false if !obj.body.eql?(self.body)
        return true
    end
    def eql?(obj)
        return self == obj
    end
    def empty?
        return true if id==nil
    end
    def to_s
        return "<Node node=id:#{@id},body:#{@body}>"
    end
    def to_json
        body = @body
        body["id"] = @id if !body.has_key?("id")
        return _to_json(body)
    end
end

class Edge 
    attr_accessor :source, :target, :label
    def initialize(source=Node.new, target=Node.new, label="points_to")
        @source = source
        @target = target
        @label = label
    end

    def to_s
        return "<Edge source: #{@source.id} label: #{@label} target: #{@target.id}>"
    end
end
