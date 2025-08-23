import 'express-serve-static-core';

declare module 'express-serve-static-core' {
  interface Request {
    user?: {
      provider: string;
      sub: string;
      email?: string;
      name?: string;
      picture?: string;
    };
  }
}


