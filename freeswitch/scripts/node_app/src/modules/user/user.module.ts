import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { userschema, UserSchema } from './user.schema';


@Module({
    imports:[MongooseModule.forFeature([ { name : UserSchema.name , schema : userschema } ])],
    // controllers : [TrunkController],
    // providers : [TrunkService]
    exports: [ MongooseModule ]
})
export class UserModule {}

