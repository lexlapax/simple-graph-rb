require 'sqlite3'
require 'json'
require_relative 'const'
require_relative 'utils'
module GraphStore
    module_function 

    def _atomic(dbfile, fn, debug:false)
        ret = nil
        begin
            db = SQLite3::Database.open(dbfile)
            if debug
                db.trace {|sqltrace| puts sqltrace }
            end 
            db.results_as_hash = true
            db.execute("PRAGMA foreign_keys = TRUE;")
            ret = fn.call(db)
        rescue => exception
            puts exception
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
        data = Utils.parse_json(body)
        data = _set_id(id, data)
        _inner_function = lambda {|sqldb|
            # puts data
            res = []
            sqldb.execute(INSERT_NODE, Utils.create_json(data)).each{ |somerow| 
                res.append(somerow)
            }
            # if !rset.close? then rset.close end
            return res
        }
        return _atomic(dbfile, _inner_function, debug:debug)
    end

    def _set_id(id, data)
        data["id"] = id.to_s if !data.key?("id")
        return data
    end

    def connect_nodes(dbfile, source_id, target_id, props={}, debug:false)
        _inner_function = lambda {|sqldb|
            res = []
            sqldb.execute(INSERT_EDGE, ["#{source_id}", "#{target_id}", Utils.create_json(props)]).each {|somerow|
                res.append(somerow)
            }
            return res
        }
        return _atomic(dbfile, _inner_function, debug:debug)
    end

end 

