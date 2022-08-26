sqlfile = "json_graph_sqlite3.sql"
sqlfiledir="#{ENV['HOME']}/projects/per/simple-graph-rb/simple-graph/sql"
dirs=Dir.children(sqlfiledir)
File.open(sqlfile, 'w+') do |fh|
    fh.write("-- timestamp #{Time.now}\n")
    fh.write("-- combining sql files from #{sqlfiledir}\n")
    dirs.sort.each do |filename|
        if filename.end_with? ".sql" 
            file = File.read(sqlfiledir + "/" + filename)
            fh.write("-- #{filename}\n")
            fh.write(file)
            fh.write("\n\n")
        end
    end
end