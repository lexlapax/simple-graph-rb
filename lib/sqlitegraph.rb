require 'sqlite3'
require 'json'
require 'graphviz'

class SQLiteGraphDb

    def initialize db_file, schema = "schema.sql"
        
    end


end


class Node
    attr_accessor :id, :labels, :props
    def initialize id 
        self.id = id
        self.labels = Array.new
        self.props = Hash.new
    end
end

class Edge
    attr_accessor :source, :target, :type, :props

    def initialize source, target
        self.source = source
        self.target = target
        self.props = Hash.new
        self.type = ""
    end
end
