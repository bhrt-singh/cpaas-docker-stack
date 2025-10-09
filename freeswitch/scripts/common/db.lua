mongo = require 'mongo'
-- local mongo_client = mongo.Client "mongodb://inextrix:4Gc5fXwqN4BazAdc@127.0.0.1/db_pbxcc?connectTimeoutMS=5000&socketTimeoutMS=20000"
local mongo_client = mongo.Client "mongodb://mongoadmin:secret@127.0.0.1:27017/db_pbxcc?authSource=admin"
--local mongo_client = mongo.Client "mongodb://inextrix:4Gc5fXwqN4BazAdc@127.0.0.1/db_pbxcc"

-- select the database and collection
mongo_collection_name = mongo_client:getDatabase "db_pbxcc"
logger_flag = 0
params_log  = 0
--mongo_connection = mongo.Client('mongodb://128.140.53.103')
--mongo_collection_name = 'inextrix_call_center'
--local collection = client:getCollection('call_center', 'test')




