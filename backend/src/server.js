const cfg = require('./config');
const express = require('express'), http = require('http'), cors = require('cors'), helmet = require('helmet'), mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const { Admin } = require('./models');

const app = express();
app.set('trust proxy', 1);
app.use(helmet());
app.use(cors({ origin: cfg.cors === '*' ? true : cfg.cors.split(',') }));
app.use(express.json({ limit: '50kb' }));
app.get('/', (_q, r) => r.json({ ok: true, name: 'GangSound API' }));
app.use('/api', require('./routes'));

const server = http.createServer(app);
require('./sockets')(server, cfg);

// Push the admin from .env into the database on every start
async function seedAdmin() {
  const username = cfg.adminUser.trim().toLowerCase();
  await Admin.deleteMany({ username: { $ne: username } }); // .env is the only source of truth
  const a = await Admin.findOne({ username });
  if (!a) {
    await Admin.create({ username, passwordHash: await bcrypt.hash(cfg.adminPass, 10) });
    console.log(`Admin "${username}" created in database`);
  } else if (!(await bcrypt.compare(cfg.adminPass, a.passwordHash))) {
    a.passwordHash = await bcrypt.hash(cfg.adminPass, 10);
    await a.save();
    console.log(`Admin "${username}" password updated from .env`);
  } else {
    console.log(`Admin "${username}" already in database`);
  }
}

mongoose.connect(cfg.mongo)
  .then(async () => {
    await seedAdmin();
    server.listen(cfg.port, () => console.log(`GangSound API on :${cfg.port}`));
  })
  .catch((e) => { console.error('Startup failed:', e.message); process.exit(1); });