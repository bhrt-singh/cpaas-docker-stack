// import { NestFactory } from '@nestjs/core';
// import mongoose from 'mongoose';
// import { AppModule } from './app.module';
// import helmet from 'helmet';
// import { Logger } from '@nestjs/common';
// import * as fs from "fs";
import * as dotenv from 'dotenv';
dotenv.config();
// //Create SSL SERVER
// // const httpsOptions = {
// // };
// //End
// //Just for development purpose
// let debug = process.env.ENVIRONMENT == 'development' ? true : false;
// mongoose.set( 'debug', debug );
// //End
// async function bootStrap () {
//   const app = await NestFactory.create( AppModule, {
//     logger: process.env.ENVIRONMENT == 'development' ? [ 'debug', 'error', 'log', 'verbose', 'warn' ] : [ 'error' ],
//     // httpsOptions
//   } );
//   app.enableCors();

//   app.use( helmet( { crossOriginResourcePolicy: false } ) ); // Protect HTTP Headers

//   await app.listen( 3002, () => {
//     // let server = app.getHttpServer(); // HTTP server
//     // server.keepAliveTimeout = 300000; // Set the keep-alive timeout (e.g., 5 minutes)
//     Logger.log( `[Nest API] Server is running on port ==> ${process.env.NEST_JS_SERVER_PORT}` );
//   } );
// }
// bootStrap();


import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { Logger } from '@nestjs/common';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  // console.log(process.env);
  await app.listen(process.env.NEST_JS_SERVER_PORT);

  Logger.log(`[Nest API] Server is running on port ==> ${process.env.NEST_JS_SERVER_PORT}`);
}
bootstrap();
