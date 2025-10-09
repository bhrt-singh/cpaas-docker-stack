--function config()
	--scripts_dir = '/usr/local/freeswitch/scripts/'
	--sounds_dir = '/usr/local/freeswitch/scripts/audio'
	--upload_file_path = '/var/www/html/backend/beltalk/upload'
	--upload_file_path = '/opt/caching/upload/en'
--end


local config = {}

-- Define all expected variables and default values
local env_vars = {
    SCRIPTS_DIR = "/usr/local/freeswitch/scripts/",
    UPLOAD_FILE_PATH = "/opt/caching/upload/en",
    SOUNDS_DIR = "/usr/local/freeswitch/scripts/audio",
    LOGGER_FLAG = 0,
    SMS_API_URL= "https://xcess-internal-cc.local:5000/sms/send",
    COMMON_ACCOUNT_NO = "A20257175258",
    MAX_ACCOUNT_NO_DIGIT = 7,
    CRM_API_URL = "https://adoptnettech.in:30080/api/v1",
    CRM_API_TOKEN = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ7XCJ1c2VybmFtZVwiOlwiYWRtaW5cIixcImZpcnN0TmFtZVwiOlwiYWRtaW5cIixcImxhc3ROYW1lXCI6XCJhZG1pblwiLFwidXNlcklkXCI6MixcInBhcnRuZXJJZFwiOjEsXCJyb2xlc0xpc3RcIjpcIjFcIixcInNlcnZpY2VBcmVhSWRcIjpudWxsLFwibXZub0lkXCI6MixcInNlcnZpY2VBcmVhSWRMaXN0XCI6W10sXCJzdGFmZklkXCI6MixcImJ1SWRzXCI6W10sXCJyb2xlSWRzXCI6WzFdLFwidGVhbUlkc1wiOlsxXSxcIm12bm9OYW1lXCI6XCJhZG1pblwiLFwibGNvXCI6ZmFsc2UsXCJ0ZWFtc1wiOltcIlBhcmVudFRlYW1cIl19IiwiZXhwIjoxNzUzNDUxMTI0fQ.lec0IcumerHzpbhzmgBoIWU7B3Vw1ZZArLty-nrB6g4"
  
}

-- Load from Docker environment first
for key, default in pairs(env_vars) do
    config[key] = os.getenv(key)
end

-- Load from .env file (only if not already set by Docker)
local function load_env_file(filepath)
    local file = io.open(filepath, "r")
    if not file then return end
    for line in file:lines() do
        local key, val = string.match(line, "^([%w_]+)%s*=%s*(.+)$")
        if key and val and not config[key] then
            config[key] = val
        end
    end
    file:close()
end

load_env_file("/usr/local/freeswitch/scripts/.env")

-- Fallback defaults
for key, default in pairs(env_vars) do
    config[key] = config[key] or default
end

-- Optional: export as globals for easy use
scripts_dir = config.SCRIPTS_DIR
upload_file_path = config.UPLOAD_FILE_PATH
sounds_dir = config.SOUNDS_DIR
SMS_API_URL = config.SMS_API_URL
COMMON_ACCOUNT_NO = config.COMMON_ACCOUNT_NO
MAX_ACCOUNT_NO_DIGIT = config.MAX_ACCOUNT_NO_DIGIT
CRM_API_URL = config.CRM_API_URL
CRM_API_TOKEN = config.CRM_API_TOKEN
LOGGER_FLAG = config.LOGGER_FLAG

return config
