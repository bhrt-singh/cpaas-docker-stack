import { XmlParserMiddleware } from './xml-parser.middleware';

describe('XmlParserMiddleware', () => {
  it('should be defined', () => {
    expect(new XmlParserMiddleware()).toBeDefined();
  });
});
