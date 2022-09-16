require 'json'
module Utils
    module_function
    def parse_json(object)
        return object if object.class != String
        return JSON.parse(object)
    end

    def create_json(object)
        return object if object.class == String
        return JSON.generate(object)
    end
end