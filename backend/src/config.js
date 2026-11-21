require('dotenv').config();
for (const k of ['MONGO_URI', 'JWT_SECRET', 'ADMIN_USERNAME', 'ADMIN_PASSWORD']) {
  if (!process.env[k]) { console.error(`Missing env value: ${k}`); process.exit(1); }
}
module.exports = {
  port: +process.env.PORT || 4000,
  mongo: process.env.MONGO_URI,
  jwt: process.env.JWT_SECRET,
  adminUser: process.env.ADMIN_USERNAME,
  adminPass: process.env.ADMIN_PASSWORD,
  cors: process.env.CORS_ORIGIN || '*',
  ice() {
    const s = [{ urls: process.env.STUN_URL || 'stun:stun.l.google.com:19302' }];
    if (process.env.TURN_URL) s.push({ urls: process.env.TURN_URL, username: process.env.TURN_USERNAME, credential: process.env.TURN_CREDENTIAL });
    return s;
  },
};
