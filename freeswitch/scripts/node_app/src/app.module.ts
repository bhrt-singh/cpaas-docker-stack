// app.module.ts
import { Module, MiddlewareConsumer, RequestMethod } from '@nestjs/common';
import { XmlParserMiddleware } from './xml-parser.middleware';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { MongooseModule } from '@nestjs/mongoose';
// import { TenantSchema } from './modules/tenant/tenant.schema';
import { TenantModule } from './modules/tenant/tenant.module';
import { UserModule } from './modules/user/user.module';
import {ExtensionModule } from './modules/extension/extension.module';

@Module({
  imports: [TenantModule,UserModule,ExtensionModule,MongooseModule.forRoot( process.env.MONGO_URI )],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {
  configure(consumer: MiddlewareConsumer) {
    consumer
      .apply(XmlParserMiddleware)
      .forRoutes({ path: '*', method: RequestMethod.ALL });
  }
}



