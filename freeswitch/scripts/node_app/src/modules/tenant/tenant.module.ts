import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { tenantSchema, TenantSchema } from './tenant.schema';


@Module({
    imports:[MongooseModule.forFeature([ { name : TenantSchema.name , schema : tenantSchema } ])],
    // controllers : [TrunkController],
    // providers : [TrunkService]
    exports: [ MongooseModule ]
})
export class TenantModule {}

