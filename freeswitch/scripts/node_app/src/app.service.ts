import { Injectable, Res  } from '@nestjs/common';
import { InjectModel } from "@nestjs/mongoose";
import { Model } from "mongoose";
import { createDecipheriv } from 'crypto';
import { Request } from 'express';
import * as fs from "fs";
import { TenantDocument, TenantSchema } from "./modules/tenant/tenant.schema";
import { UserDocument,UserSchema } from './modules/user/user.schema';
import { ExtensionDocument,ExtensionSchema } from './modules/extension/extension.schema';

@Injectable()
export class AppService {

  constructor(
    @InjectModel( TenantSchema.name ) private readonly tenant: Model<TenantDocument>,
    @InjectModel( UserSchema.name ) private readonly user: Model<UserDocument>,
    @InjectModel( ExtensionSchema.name ) private readonly extensions: Model<ExtensionDocument>,
  ){ }



   async getuserinfo(Request) : Promise<string> {
    //console.log(Request);
    //console.log(Request.user);
    //console.log(Request.domain);
    let tenantarray:any;
    let extension:any;
    let user:any;
    let xml_string = '';
    tenantarray = await this.tenant.findOne({domain:Request.domain}).exec();
    // console.log(tenantarray['uuid']);
    // console.log(tenantarray);
    
    if(tenantarray != null){
       extension = await this.extensions.findOne({username:Request.user,tenant_uuid:tenantarray['uuid']}).exec();
      //console.log(extension);

      if(extension != null){
        user =   await this.user.findOne({default_extension:extension['uuid']}).exec()
       	if(user != null){
      		xml_string =  await this.generateuserxml(Request,tenantarray,user,extension); 	
	}else{
		xml_string = `<?xml version="1.0" encoding="UTF-8" standalone="no"?>
                        <document type="freeswitch/xml">
                                <section name="result">
                                        <result status="not found" />
                                </section>
                        </document>`;	
	}
      }else{
      	xml_string = `<?xml version="1.0" encoding="UTF-8" standalone="no"?>
                        <document type="freeswitch/xml">
                                <section name="result">
                                        <result status="not found" />
                                </section>
                        </document>`;

      }
    }else{
      xml_string = `<?xml version="1.0" encoding="UTF-8" standalone="no"?>
			<document type="freeswitch/xml">
				<section name="result">
					<result status="not found" />
				</section>
			</document>`;
    }

     

  
    

    
    //console.log(xml_string);
    
    // }
    return xml_string;

    // let xml_string = '';

    // try {
    //     xml_string = await this.generateuserxml(Request);
    //     console.log(xml_string);
    //     return xml_string;
    // } catch (error) {
    //     console.error("Error generating user XML:", error);
    //     throw error;
    // }
     
    // res.set('Content-Type', 'application/xml');
    // res.send(xml_string);
    // res.status(200).send(xml_string);
  }

  async generateuserxml(Request,tenantarray,user,extension){
    
    let { voicemail_status, vmpassword, mail_to, attach_file } = extension['voicemail'];
    voicemail_status == '0'? 'true' :'false';
    let password = this.decode(extension['password']);
    let xml = '';
    xml += '<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n';
    xml += '<document type="freeswitch/xml">\n';
    xml += '<section name="directory">\n';
    xml += `<domain name="${tenantarray['domain']}" alias="true">\n`;
    xml += '<params>\n';
    xml += '<param name="jsonrpc-allowed-methods" value="verto"/>\n';
    xml += '<param name="jsonrpc-allowed-event-channels" value="demo,conference,presence"/>\n';
    xml += '</params>\n';
    xml += '<groups>\n';
    xml += '<group name="default">\n';
    xml += '<users>\n';
    xml += `<user id="${extension['username']}">\n`;
    xml += `<params>`;
    xml += `<param name="password" value="${password}"/>\n`;
    xml += `<param name="vm-enabled" value="${voicemail_status}"/>\n`;
    xml += `<param name="vm-password" value="${vmpassword}"/>\n`;
    xml += `<param name="vm-mailto" value="${mail_to}"/>\n`;
    xml += `<param name="vm-attach-file" value="${attach_file}"/>\n`;
    xml += `<param name="vm-keep-local-after-email" value="true"/>\n`;
    xml += `<param name="vm-email-all-messages" value="true"/>\n`;
    xml += '<param name="dial-string" value="{sip_invite_domain=${domain_name},leg_timeout=${call_timeout},presence_id=${dialed_user}@${dialed_domain}}${sofia_contact(*/${dialed_user}@${dialed_domain})}"/>\n';
    xml += `</params>\n`;
    xml += `<variables>\n`;
    xml += `<variable name="tenant_uuid" value="${tenantarray['uuid']}"/>\n`;
    xml += `<variable name="domain_name" value="${tenantarray['domain']}"/>\n`;
    xml += `<variable name="extension_uuid" value="${extension['uuid']}"/>\n`;
    xml += `<variable name="user_uuid" value="${user['uuid']}"/>\n`;
    xml += `<variable name="caller_id_name" value="${extension['caller_id_name']}"/>\n`;
    xml += `<variable name="caller_id_number" value="${extension['caller_id_number']}"/>\n`;
    xml += `<variable name="presence_id" value="${extension['username']}@${tenantarray['domain']}"/>\n`;
    xml += '<variable name="directory-visible" value="true"/>\n';
    xml += `<variable name="user_context" value="${tenantarray['domain']}"/>\n`;
    xml += `<variable name="directory-visible" value="true"/>\n`;
    xml += `<variable name="directory-exten-visible" value="true"/>\n`;
    xml += `<variable name="limit_max" value="5"/>\n`;
    xml += `<variable name="limit_destination" value="!USER_BUSY"/>\n`;
    xml += `<variable name="record_stereo" value="true"/>\n`;
    xml += `<variable name="record_stereo" value="true"/>\n`;
    xml += `<variable name="export_vars" value="domain_name,domain_uuid"/>\n`;
    xml += `</variables>\n`;
    xml += `</user>\n`;
    xml += `</users>\n`;
    xml += `</group>\n`;
    xml += `</groups>\n`;
    xml += `</domain>\n`;
    xml += `</section>\n`;
    xml += `</document>`;

    xml += ``
    
    return xml;


  }

  decode ( value ) {
    const decipher = createDecipheriv( process.env.ALGORITHM, process.env.ENCRYPTION_KEY, process.env.PASSWORD_LENGTH );
    let decryptedData = decipher.update( value, "hex", "utf-8" );
    decryptedData += decipher.final( "utf8" );
    return decryptedData;
  }

}

//   async generateTenantXml(extensionDetails, decodePassword, extensionUUID, voicemail) {
//     const { username, caller_id_name, caller_id_number, tenant_uuid, user_uuid } = extensionDetails;
//     const { voicemail_status, password, mail_to, attach_file } = voicemail;
    
//     let extPassword = decodePassword;
//     // const getExtension = await this.tenant.findOne({ uuid: extensionDetails.tenant_uuid }, { domain: 1 }).exec();
//     // var tenant;
//     // if (getExtension) {
//     //     tenant = (getExtension.domain == "" || getExtension.domain == null) ? 'beltalk.inextrix.com' :
//     //         getExtension.domain;
//     // } else {
//     //     // Logger.debug(`GenerateTenatXML tenant not found by uuid : ${extensionDetails.tenant_uuid} \n`);
//     // }

//     //Directory DATA
//     var file_path_directory = `${process.env.READ_TENANT_XML}`;
//     var data_dir = fs.readFileSync(file_path_directory, 'utf8');
//     var directory_data = data_dir.toString();

//     //Extension details
//     directory_data = directory_data.replaceAll('#EXT_USERNAME#', username);
//     directory_data = directory_data.replaceAll('#TENANT#', tenant);
//     directory_data = directory_data.replaceAll('#EXT_PASSWORD#', extPassword);
//     directory_data = directory_data.replaceAll('#TENANT_UUID#', tenant_uuid);
//     directory_data = directory_data.replaceAll('#USER_UUID#', user_uuid);
//     directory_data = directory_data.replaceAll('#EXTENSION_UUID#', extensionUUID);
//     directory_data = directory_data.replaceAll('#EXT_CID_NAME#', caller_id_name);
//     directory_data = directory_data.replaceAll('#EXT_CID_NUMBER#', caller_id_number);
//     //Voicemail details
//     directory_data = directory_data.replaceAll('#VOICEMAIL_STATUS#', voicemail_status == 0 ? "true" : "false");
//     directory_data = directory_data.replaceAll('#VOICEMAIL_PASSWORD#', password);
//     directory_data = directory_data.replaceAll('#VOICEMAIL_MAIL#', mail_to);
//     directory_data = directory_data.replaceAll('#VOICEMAIL_ATTACH#', attach_file);

//     // var directory_file_name = `${process.env.EXTENSION_DIRECTORY}${username}.${tenant}.xml`;
//     // fs.writeFileSync(directory_file_name, directory_data.toString());
//     // console.log(directory_file_name);
//     // Logger.debug(`File written successfully with : ${username}.${tenant}.xml \n`);

// }  



// }
