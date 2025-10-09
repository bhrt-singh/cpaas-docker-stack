import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { extensionschema, ExtensionSchema } from './extension.schema';


@Module({
    imports:[MongooseModule.forFeature([ { name : ExtensionSchema.name , schema : extensionschema } ])],
    // controllers : [TrunkController],
    // providers : [TrunkService]
    exports: [ MongooseModule ]
})
export class ExtensionModule {}

