require 'sqlite3'
require_relative 'const'
require_relative 'utils'
include Utils
module GraphStore

    module_function 

    #generic functions for generating sql "=", like statements
    def sql_where_equals(props, predicate="=")
        props.map{|key, value|
            " json_extract(body, '$.#{key}') #{predicate} ?"
        }.join(" AND ")
    end

    def sql_where_like(props)
        return sql_where_equals(props, 'LIKE')
    end
    def sql_cond_equals(props)
        return props.values
    end
    def sql_cond_starts(props)
        return props.values.collect {|val| "#{val}%" }
    end
    def sql_cond_contains(props)
        return props.values.collect {|val| "%#{val}%" }
    end    

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
            rset = sqldb.execute_batch(SCHEMA)
            # if rset != nil 
            #     rset.each{ |somerow|
            #         res.append(somerow)
            #     }
            #     if !rset.close? then rset.close end
            # end
            return res
        }
        return _atomic(dbfile, inner_function, debug:debug)
    end

    def add_node(dbfile, body, id, debug: false)
        data = _set_id(id, parse_json(body))
        _inner_function = lambda {|sqldb|
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
            rs = sqldb.execute(SEARCH_NODE_BY_ID, [id.to_s])
            if rs!= nil && ! rs.empty? 
                res = parse_json(rs[0]["body"])
            end
            return res
        }
        return _atomic(dbfile, _inner_function, debug:debug)
    end


    def find_nodes(dbfile,props={}, where_fn=:sql_where_equals, search_fn=:sql_cond_equals, debug:false)
        _inner_function = lambda {|sqldb|
            res = []
            if props == nil or props == {} 
                # find everythin
                rows=sqldb.execute(SEARCH_NODE.chomp("WHERE"))
            else
                rows=sqldb.execute(SEARCH_NODE + send(where_fn, props), send(search_fn, props))
            end
            rows.map { |row|
                    res.append(parse_json(row["body"]))
            }
            return res
        }
       return _atomic(dbfile, _inner_function, debug:debug)
    end

    def remove_node(dbfile, id, debug:false)
        _inner_function = lambda {|sqldb|
            sqldb.execute(DELETE_EDGE, [id, id])
            sqldb.execute(DELETE_NODE, [id])
        }
        _atomic(dbfile, _inner_function, debug:debug)
    end

    def add_nodes(dbfile, bodies, ids, debug: false)
        _inner_function = lambda {|sqldb|
            sqls = bodies.map { |bodystr|
                sqlstr = INSERT_NODE.sub(/\?/, "'#{create_json(bodystr)}'") 
            }.join(";\n")
            sqls += "\n;"
            sqldb.execute_batch(sqls)
        }
        #_add_nodes_prep_sql(bodies)
        return _atomic(dbfile, _inner_function, debug: debug)
    end

    def upsert_nodes(dbfile, bodies, ids, debug: false)
        for i in 0..ids.length-1
            upsert_node(dbfile, bodies[i],ids[i], debug: debug)
        end
        return nil
    end

    def find_edges(dbfile, source:nil, target:nil, debug: false)
        _inner_function = lambda {|sqldb|
            res = []
            case [source, target]
            in [nil, nil]
                # sqls = SEARCH_EDGE_IB.chomp(" WHERE source = ?")
                res = sqldb.execute(SEARCH_EDGES_INBOUND.chomp(" WHERE source = ?"))
            in [nil, x]
                # sqls = "#{SEARCH_EDGE_OB} target=#{x}" 
                res = sqldb.execute(SEARCH_EDGES_OUTBOUND, [target])
            in [x, nil]
                # sqls = "#{SEARCH_EDGE_IB} source=#{x}" 
                res = sqldb.execute(SEARCH_EDGES_INBOUND, [source])
            else
                # sqls = "#{SEARCH_EDGES} source=#{source} target=#{target}"
                res = sqldb.execute(SEARCH_EDGES, [source, target])
            end
            return res
        }
        return _atomic(dbfile, _inner_function, debug: debug)
    end

    def connect_many_nodes(dbfile, sources, targets, props, debug:false)
        _inner_function = lambda {|sqldb|
            sqls = ""
            [sources, targets, props].transpose.each {|src, tgt, label|
                sqls = sqls+ INSERT_EDGE.sub(/\?/, "#{src}").sub(/\?/,"#{tgt}").sub(/\?/,"'#{create_json(label)}'")+";\n"
                }
            sqldb.execute_batch(sqls)
            }
            return _atomic(dbfile, _inner_function, debug: debug)
    end

    def remove_nodes(dbfile, ids, debug:false)
        _inner_function = lambda {|sqldb|
            sql_edge = ""
            sql_node = ""
            ids.each {|id|
                sql_edge = sql_edge + DELETE_EDGE.sub(/\?/,"#{id}").sub(/\?/,"#{id}") + ";\n"
                sql_node = sql_node + DELETE_NODE.sub(/\?/,"#{id}") +";\n"
            }
            sqldb.execute_batch( sql_edge + sql_node)
        }
        return _atomic(dbfile, _inner_function, debug: debug)
    end

    def traverse(dbfile, src, tgt=nil, neighbors_fn:"neighbors", bodies:false, debug:false)
        _inner_function = lambda{|sqldb|
            path = []
            target = create_json(tgt)
            sql=""
            case neighbors_fn
            in "outbound" 
                if bodies 
                    sql = TRAVERSE_WITH_BODIES_OUTBOUND
                else
                    sql = TRAVERSE_OUTBOUND
                end
            in "inbound"
                if bodies
                    sql = TRAVERSE_WITH_BODIES_INBOUND
                else
                    sql = TRAVERSE_INBOUND
                end
            in "neighbors"
                if bodies
                    sql = TRAVERSE_WITH_BODIES
                else
                    sql = TRAVERSE
                end
            end
            sqldb.execute(sql, {'source': create_json(src)}).each {|row|
                # puts row
                if bodies
                    # deconstruct array using pattern matching (ruby3)
                    row.values => [id, obj, body]
                    # puts "#{id} #{connector} #{obj}"
                    path.append([id, obj, parse_json(body)])
                    if id == target && obj == '()'
                        break
                    end
                else
                    id = row['id']
                    path.append(id) if !path.include?(id)
                    break if id == target
                end
            }
            return path
        }
        return _atomic(dbfile, _inner_function, debug: debug)
    end
end 

