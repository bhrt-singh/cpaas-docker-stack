-- Function to execute shell command
function execute_command(command)
    local handle = io.popen(command)
    local result = handle:read("*a")
    handle:close()
    return result
end
local json = require("cjson")

-- MongoDB connection parameters
local host = "127.0.0.1"
local port = 27017
local databaseName = "db_pbxcc"
local username = "inextrix"
local password = "4Gc5fXwqN4BazAdc"
local collectionName = "tenant"

-- MongoDB connection URI inextrix:4Gc5fXwqN4BazAdc@127.0.0.1/db_pbxcc
local uri = string.format("mongodb://%s:%s@%s:%d/%s", username, password, host, port, databaseName)

-- Example select query
local query = "{ 'tenant_name': 'anup test' }"

-- Constructing the mongo shell command
local command = string.format('mongo "%s" --quiet --eval "db.%s.find(%s)"', uri, collectionName, query)
print(command)
-- Executing the command and capturing output
--local result = json.encode(execute_command(command))
local result = json.encode(execute_command(command))
-- Output the result
local result_new = json.decode(result)
for key, value in pairs(result_new) do
    print(key .. ": " .. value)
end
print(result_new)

