// import { Logger , Body, Controller, Delete, Get, Param, ParseUUIDPipe, Patch, Post, Put, Query ,Req, Res } from "@nestjs/common"; 
// import { AppService } from './app.service';
// import { Request } from 'express';

// @Controller()
// export class AppController {
//   constructor(private readonly appService: AppService) {}

//   @Get()
//   getHello(@Req() request: Request) {
//     // console.log(request.query); // Access query parameters
//     // console.log(request.params); // Access route parameters
//     // console.log(request.body); // Access request body
//     // console.log(request.headers); // Access request headers
//     // Access other request properties as needed
    
//     return this.appService.getHello(request);
//   }
// }

// example.controller.ts
import { Controller, Post, Body,Res } from '@nestjs/common';
import { AppService } from './app.service';
import * as fs from "fs";

@Controller()
export class AppController {

  constructor(private readonly appService: AppService) {}
  @Post()
  async handleXmlRequest(@Body() xmlData: any ,@Res() res) {
    // console.log(xmlData); // Process the XML data
    // console.log(xml_string);

    let xml_string = await this.appService.getuserinfo(xmlData);

    res.set('Content-Type', 'application/xml');
    // res.send(xml_string);
    // console.log(xml_string)
    res.status(200).send(xml_string);
      // return xml_string;
  }
}





