require 'sqlite3'

# def sqlite_query(db_file, query, debug=false)
#     begin
#         db = SQLite3::Database.open(db_file)
#         if debug
#             db.trace {|sqltrace|
#                 puts "#{sqltrace}"
#             }
#         end
#         db.results_as_hash = true
#         return db.execute(query)
#     rescue Exception => e
#         puts e
#     ensure
#         db.close if db
#     end
#     return nil
# end
# def init_db(db_file, debug=false)
#     begin
#         db = SQLite3::Database.open(db_file)
#         if debug
#             db.trace {|sqltrace|
#                 puts "#{sqltrace}"
#             }
#         end
#         db.results_as_hash = true
#         db.execute("PRAGMA foreign_keys = TRUE;")
#         ret = db.execute_batch("""CREATE TABLE IF NOT EXISTS nodes (
#             body TEXT,
#             id   TEXT GENERATED ALWAYS AS (json_extract(body, '$.id')) VIRTUAL NOT NULL UNIQUE
#         );""")
#     rescue => err
#         puts err
#         raise err
#     ensure
#         db.close if db
#     end

# end

def outer_function(sql_stmt)
    inner_function = lambda {|db|
            return ["inner = #{db}", "outer = #{sql_stmt}"]
    }
    return inner_function   
end

def calling_function(something)
    fn = outer_function(something)
    fn.call("should be inner")
end

if __FILE__ ==$0
    puts calling_function("should be outer").class
end