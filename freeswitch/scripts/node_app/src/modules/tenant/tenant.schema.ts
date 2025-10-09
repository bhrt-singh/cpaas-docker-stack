import { Prop, Schema, SchemaFactory } from "@nestjs/mongoose";
import { Document } from "mongoose";
import { randomUUID } from "crypto";

export type TenantDocument = TenantSchema & Document;

@Schema({ collection: "tenant", timestamps: true  , toJSON: { virtuals: true, getters: true }, toObject: { virtuals: true, getters: true }})

export class TenantSchema {

    @Prop({ type: String, default: function genUUID() { return randomUUID(); }, unique: true })
    uuid: String

    @Prop()
    tenant_name: String;

    @Prop()
    username: String;

    @Prop()
    password: String;

    @Prop({ is_unique: true })
    domain: String;

    @Prop()
    status: String;

    @Prop()
    time_zone_uuid: String

    @Prop()
    email: String

    @Prop()
    role_uuid: String

    @Prop()
    country_uuid: String

    @Prop()
    creation_uuid: String

    @Prop()
    update_uuid: String

    @Prop()
    tenant_uuid?: String
    
    @Prop()
    sip_profile_uuid: String
    
    @Prop()
    role?: String

    @Prop()
    outgoing_rule_uuid: String

    @Prop()
    concurrent_calls: String

    @Prop()
    web_hook : String

    @Prop({ default : "1" })
    add_anonymous_lead : String

    @Prop()
    mail_link_status : String

    @Prop()
    timezoneName? : String
}

export const tenantSchema = SchemaFactory.createForClass(TenantSchema);