import { Prop, Schema, SchemaFactory } from "@nestjs/mongoose";
import { Document } from "mongoose";
import { randomUUID } from "crypto";
import { call_forward, follow_me, speed_dial, voicemail } from "./extension-utils";

export type ExtensionDocument = ExtensionSchema & Document

@Schema( { collection: "extensions", timestamps: true, toJSON: { virtuals: true, getters: true }, toObject: { virtuals: true, getters: true } } )

export class ExtensionSchema {

    @Prop( { type: String, default: function radomUUID () { return randomUUID() } } )
    uuid: string

    @Prop()
    device_name: String

    @Prop()
    username: String

    @Prop()
    password: String

    @Prop()
    user_uuid: String

    @Prop()
    status: String

    @Prop( { default: "1" } )
    recording: String

    @Prop( { default: "1" } )
    dnd: String

    @Prop( { default: "" } )
    mail_to: String

    @Prop()
    caller_id_name: String

    @Prop()
    caller_id_number: String

    @Prop()
    tenant_uuid: String

    @Prop( { type: Object, default: call_forward } )
    call_forward: object

    @Prop( { type: Object, default: voicemail } )
    voicemail: object

    @Prop( { type: Object, default: follow_me } )
    follow_me: object

    @Prop( { type: Object, default: speed_dial } )
    speed_dial: Object

    @Prop( { default: "1" } )
    extension_status: String

    @Prop( { default: "1" } )
    is_assigned: String

    tenant?: String

    user?: String
}

export const extensionschema = SchemaFactory.createForClass(ExtensionSchema);