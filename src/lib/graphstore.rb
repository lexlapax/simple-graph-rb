require 'sqlite3'
require_relative 'const'
require_relative 'utils'
include Utils
module GraphStore

    module_function 

    def _atomic(dbfile, fn, debug:false)
        ret = nil
        # debug = true
        begin
            db = SQLite3::Database.open(dbfile)
            if debug
                db.trace {|sqltrace| puts sqltrace }
            end 
            db.results_as_hash = true
            db.execute("PRAGMA foreign_keys = TRUE;")
            ret = fn.call(db)
        rescue => exception
            puts "sqlite error: #{exception}"
            raise exception
        ensure
            db.close if db
        end
        return ret
    end

    def initialize(dbfile="graph.db", debug: false)
        inner_function = lambda{|sqldb| 
            res = []
            rset = sqldb.execute_batch(GRAPH_SCHEMA)
            if rset != nil 
                rset.each{ |somerow|
                    res.append(somerow)
                }
                if !rset.close? then rset.close end
            end
            return res
        }
        return _atomic(dbfile, inner_function, debug:debug)
    end

    def add_node(dbfile, body, id, debug: false)
        data = _set_id(id, parse_json(body))
        _inner_function = lambda {|sqldb|
            # puts data
            res = []
            sqldb.execute(INSERT_NODE, create_json(data)).each{ |somerow| 
                res.append(somerow)
            }
            # if !rset.close? then rset.close end
            return res
        }
        return _atomic(dbfile, _inner_function, debug:debug)
    end

    def upsert_node(dbfile, body, id, debug: false)
        node = find_node(dbfile, id, debug: debug)
        _inner_function = lambda {|sqldb|
            res = []
            res = sqldb.execute(UPDATE_NODE, [create_json(node), id])
            return res
        }
        if node == nil or node.empty? or node == {}
            return add_node(body, id)
        else
            data = parse_json(body)
            data.delete("id")
            node = node.merge(data)
            return _atomic(dbfile, _inner_function, debug:debug)
        end
    end

    def _set_id(id, data)
        unless data.key?(:id) || data.key?("id")
            data["id"] = id.to_s 
        end
        return data
    end

    def connect_nodes(dbfile, source_id, target_id, props={}, debug:false)
        _inner_function = lambda {|sqldb|
            # puts "source: #{source_id}"
            res = []
            sqldb.execute(INSERT_EDGE, ["#{source_id}", "#{target_id}", create_json(props)]).each {|somerow|
                res.append(somerow)
            }
            return res
        }
        return _atomic(dbfile, _inner_function, debug:debug)
    end

    def find_node(dbfile, id, debug:false)
        _inner_function = lambda {|sqldb|
            res = {}
            rs = sqldb.execute(SEARCH_NODE_ID, [id.to_s])
            if rs!= nil && ! rs.empty? 
                res = parse_json(rs[0]["body"])
            end
            return res
        }
        return _atomic(dbfile, _inner_function, debug:debug)
    end

    # def find_node(id)
    #     result = atomic(@db_file, SEARCH_NODE_ID, bind_vars: [id.to_s])
    #     if result == nil or result.empty?
    #         return {}
    #     else 
    #         return Node.new(_from_json(result[0]["body"]), id)
    #     end
    # end
end 

