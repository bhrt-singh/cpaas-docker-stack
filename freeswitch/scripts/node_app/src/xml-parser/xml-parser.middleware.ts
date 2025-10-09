import { Injectable, NestMiddleware } from '@nestjs/common';

@Injectable()
export class XmlParserMiddleware implements NestMiddleware {
  use(req: any, res: any, next: () => void) {
    next();
  }
}
