#!/bin/bash

# Define the database and collection names
DATABASE_NAME="db_pbxcc"
COLLECTION_NAME="lead_management"
HOSTNAME="127.0.0.1:27017"
USERNAME="inextrix"
PASSWORD="4Gc5fXwqN4BazAdc"
AUTH_DB="db_pbxcc" # This is typically 'admin', but change if you use a different authentication database

# Start the mongo shell and execute the JavaScript
mongo --username $USERNAME --password $PASSWORD --authenticationDatabase $AUTH_DB $HOSTNAME/$DATABASE_NAME <<EOF
    var bulk = db.$COLLECTION_NAME.initializeUnorderedBulkOp();
    
    for (var i = 1; i <= 2; i++) {
        bulk.insert({
	    lead_group_uuid: '06b542ec-83f4-43b1-b8e8-a730bc143f8c',
	    first_name: 'Deep2582',
	    last_name: '',
	    postal_code: '',
	    phone_code: '91',
	    phone_number: '9196648025503',
	    user_uuid: '',
	    tenant_uuid: 'ad99844b-5410-4364-881c-03bc4dcd43a3',
	    created_flag: '1',
	    lead_status: '3809f32d-9096-406b-b2ff-1207b3fbfbc5',
	    campaign_uuid: '9f0d3179-58d2-4cbf-bdd5-ca5fc0a704ae',
	    custom_phone_number: '919196648025503',
	    call_count: 0,
	    in_dnc: '1',
	    lead_management_uuid: 'fcae7b42-1028-4ab1-8c91-948735bb481d',
    }

    bulk.execute();
EOF

