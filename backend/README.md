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

MongoDB Atlas connection string example:

mongodb+srv://<username>:<password>@<cluster-name>.mongodb.net/<database>?retryWrites=true&w=majority

## Run
npm run dev

Or build + start:

npm run build && npm start
