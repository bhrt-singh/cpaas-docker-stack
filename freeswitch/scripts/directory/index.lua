--get the params and set them as variables
        domain_name = params:getHeader("sip_from_host");
        if (domain_uuid == nil) then
                domain_uuid = params:getHeader("domain_uuid");
        end
        if (domain_name == nil) then
                domain_name = params:getHeader("domain");
        end
        if (domain_name == nil) then
                domain_name = params:getHeader("domain_name");
        end
        if (domain_name == nil) then
                domain_name = params:getHeader("variable_domain_name");
        end
        if (domain_name == nil) then
                domain_name = params:getHeader("variable_sip_from_host");
        end

        if (domain_name ~= nil) then
        	if(params_log == 0)then
	                fs_logger ("notice","1111111111[directory/index.lua][domain_name] "..domain_name)
	        end
        end
	sip_user   = params:getHeader("user");
	if(sip_user ~= nil)then
		if(params_log == 0)then
			fs_logger ("notice","[directory/index.lua][sip_user] "..sip_user)
		end
		local fname = caching_path..'directory/'..sip_user..'.'..domain_name..'.xml'
		if(params_log == 0)then
			fs_logger ("notice","[directory/index.lua][fname] "..fname)
		end
		local file, err = io.open(fname, mode or "rb")
		if not file then
			-- log.err("Can not open file to read:" .. tostring(err))
			fs_logger ("notice","[directory/index.lua][XML_STRING]"..fname.." NOT FOUND")
			return nil, err
		end
		XML_STRING = file:read("*all")
		file:close()
		fs_logger ("notice","[directory/index.lua][XML_STRING] "..XML_STRING)
	end
	if not XML_STRING then
		XML_STRING = [[<?xml version="1.0" encoding="UTF-8" standalone="no"?>
			<document type="freeswitch/xml">
				<section name="result">
					<result status="not found" />
				</section>
			</document>]];
	end
