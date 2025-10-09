import { Prop, Schema, SchemaFactory } from "@nestjs/mongoose";
import { Document } from "mongoose";
import { randomUUID } from "crypto";

export type UserDocument = UserSchema & Document

@Schema({ collection: "user", timestamps: true  , toJSON: { virtuals: true, getters: true }, toObject: { virtuals: true, getters: true }})

export class UserSchema {

    @Prop({ type: String, default: function genUUID() { return randomUUID(); }, unique: true })
    uuid: String

    @Prop()
    username : String

    @Prop()
    email : String

    @Prop()
    password : String

    @Prop()
    default_timeout : String

    @Prop()
    recording : String

    @Prop()
    status : String

    @Prop({default : ""})
    extension_type : String

    @Prop({default : ""})
    default_extension : String

    @Prop()
    tenant_uuid : String

    @Prop()
    user_role_uuid : String

    @Prop()
    user_group_uuid : String
 
    @Prop({default : "1"}) /*For web*/
    is_logged_in : String

    @Prop()
    mail_link_status: String

    /****** Below params are for mobile ******/

    @Prop({ default: "1" })
    is_logged_in_mobile: String

    @Prop({ default: "" })
    device_id: String

    @Prop({ default: "" })
    callkit_token: String

    @Prop({ default: "" })
    apns_token: String

    @Prop({ default: "" })
    mobile_type: String
    
    @Prop()
    manager_uuid: String

    @Prop()
    zoho_user_id: String
}

export const userschema = SchemaFactory.createForClass(UserSchema);