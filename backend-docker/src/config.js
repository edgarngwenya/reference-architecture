const dotenv = require('dotenv');

dotenv.config();

module.exports = {
	mongodbUrl: process.env.MONGODB_URL,
	port: process.env.PORT
};
