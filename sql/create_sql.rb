## run file like
## bundle exec ruby sql/create_sql.rb simple-graph/sql >> sql/json_graph_sqlite3.sql
#sqlfile = "json_graph_sqlite3.sql"
sqlfiledir=ARGV[0] #"simple-graph/sql"
dirs=Dir.children(sqlfiledir)
# File.open(sqlfile, 'w+') do |fh|
    puts("-- timestamp #{Time.now}\n")
    puts("-- combining sql files from #{sqlfiledir}\n")
    dirs.sort.each do |filename|
        if filename.end_with? ".sql" 
            file = File.read(sqlfiledir + "/" + filename)
            puts("-- #{filename}\n")
            puts(file)
            puts("\n\n")
        end
    end
# end