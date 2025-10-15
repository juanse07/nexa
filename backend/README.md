# Nexa Backend (Node.js + TypeScript)

## Scripts
- dev: Run with nodemon + ts-node
- build: Compile TypeScript to dist/
- start: Run compiled server

## Environment
Create a .env file:

PORT=4000
MONGO_URI=<your-mongodb-atlas-connection-string>
NODE_ENV=development
BACKEND_JWT_SECRET=<random-long-secret>
GOOGLE_CLIENT_ID_WEB=<google-web-client-id>
GOOGLE_SERVER_CLIENT_ID=<google-server-client-id>
APPLE_BUNDLE_ID=com.pymesoft.nexastaff,com.pymesoft.nexa
APPLE_SERVICE_ID=com.pymesoft.nexa.web

MongoDB Atlas connection string example:

mongodb+srv://<username>:<password>@<cluster-name>.mongodb.net/<database>?retryWrites=true&w=majority

The backend verifies Apple identity tokens against every value in `APPLE_BUNDLE_ID` and
`APPLE_SERVICE_ID`. Include your iOS bundle IDs and any web Service IDs in these comma-separated
lists so both native and web sign-ins succeed.

## Run
npm run dev

Or build + start:

npm run build && npm start
