--scripts_dir = '/usr/share/freeswitch/scripts/'
--upload_file_path = '/var/www/html/backend/beltalk/upload'
--upload_file_path = '/opt/backend/beltalk/upload'
dofile("/usr/local/freeswitch/scripts/config.lua")
caching_path = '/opt/caching/'
dofile(scripts_dir .. "common/db.lua");

local currentTimestamp = os.time()
print(currentTimestamp)
local futureTimestamp = currentTimestamp + 30
print(futureTimestamp)
--get the argv values
--scripts_dir = '/usr/share/freeswitch/scripts/'
--upload_file_path = '/var/www/html/backend/beltalk/upload'
--upload_file_path = '/opt/backend/beltalk/upload'
caching_path = '/opt/caching/'
dofile(scripts_dir .. "common/db.lua");
dofile(scripts_dir .. "common/custom.lua");
session:execute("info")
local uuid = session:getVariable("uuid");
fs_logger("notice","[auto_campaign_agent.lua][xml_REQUEST]uuid "..uuid)

local auto_campaign = session:getVariable("sip_h_P-auto_campaign");
fs_logger("notice","[auto_campaign_agent.lua]auto_campaign "..auto_campaign)
local agent_uuid = session:getVariable("sip_h_P-agent_uuid");
fs_logger("notice","[auto_campaign_agent.lua]auto_campaign "..agent_uuid)

local auto_campaign_originate = session:getVariable("sip_h_P-auto_campaign_originate");
fs_logger("notice","[auto_campaign_agent.lua]auto_campaign_originate "..auto_campaign_originate)
local lead_uuid = session:getVariable("sip_h_P-lead_uuid");
fs_logger("notice","[auto_campaign_agent.lua]lead_uuid "..lead_uuid)

session:execute("set", 'sip_h_P-auto_agent_flag=auto_agent')
local lead_originate = mongo_collection_name:getCollection "lead_originate"
local filter = { lead_management_uuid = lead_uuid }
local update = { ["$set"] = { flag = '1' } }
local result = lead_originate:update(filter, update)



local auto_campaign_camp = mongo_collection_name:getCollection "auto_campaign_originate"
local filter = { auto_campaign_originate_uuid = auto_campaign_originate }
fs_logger("notice","[auto_campaign_agent.lua]auto_campaign_originate:::----::auto_campaign_originate "..auto_campaign_originate)
local update = { ["$set"] = { flag = '1' } }
local result = auto_campaign_camp:update(filter, update)


