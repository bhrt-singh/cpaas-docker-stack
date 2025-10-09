// xml-parser.middleware.ts
import { Injectable, NestMiddleware } from '@nestjs/common';
import { Request, Response } from 'express';
import * as xml2js from 'xml2js';

@Injectable()
export class XmlParserMiddleware implements NestMiddleware {
  use(req: Request, res: Response, next: () => void) {
    if (req.is('xml')) {
      let xmlData = '';
      req.setEncoding('utf8');
      req.on('data', (chunk) => {
        xmlData += chunk;
      });
      req.on('end', () => {
        xml2js.parseString(xmlData, (err, result) => {
          if (err) {
            // Handle error
            console.error(err);
          } else {
            req.body = result;
            next();
          }
        });
      });
    } else {
      next();
    }
  }
}
