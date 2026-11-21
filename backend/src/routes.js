const router = require('express').Router();
const bcrypt = require('bcryptjs');
const rateLimit = require('express-rate-limit');
const { User, AppUpdate, Admin } = require('./models');
const { sign, safeEq, auth } = require('./auth');
const { latestFor } = require('./updates');
const cfg = require('./config');
const st = require('./state');

const limiter = rateLimit({ windowMs: 15 * 60 * 1000, max: 40 });
const W = (fn) => (q, s, n) => Promise.resolve(fn(q, s, n)).catch((e) => { console.error(e); s.status(500).json({ error: 'Server error' }); });
const ip = (r) => (r.headers['x-forwarded-for'] || r.socket.remoteAddress || '').split(',')[0];
const pub = (u) => ({ id: u.id, username: u.username, displayName: u.displayName });
const A = auth('admin');

router.post('/auth/register', limiter, W(async (req, res) => {
  const { username, password, displayName, email, phone, device, platform, appVersion } = req.body || {};
  const u = String(username || '').trim().toLowerCase();
  if (!/^[a-z0-9_]{3,20}$/.test(u)) return res.status(400).json({ error: 'Username: 3-20 chars, letters, numbers, _' });
  if (String(password || '').length < 6) return res.status(400).json({ error: 'Password needs 6+ characters' });
  if (u === cfg.adminUser.toLowerCase() || (await User.findOne({ username: u }))) return res.status(400).json({ error: 'Username taken' });
  const user = await User.create({
    username: u, displayName: displayName || u, email, phone,
    passwordHash: await bcrypt.hash(String(password), 10),
    lastIp: ip(req), lastLoginAt: new Date(), lastDevice: device, lastPlatform: platform, lastAppVersion: appVersion, loginCount: 1,
  });
  res.json({ token: sign({ id: user.id, username: u, role: 'user' }), user: pub(user) });
}));

router.post('/auth/login', limiter, W(async (req, res) => {
  const { username, password, device, platform, appVersion } = req.body || {};
  const user = await User.findOne({ username: String(username || '').trim().toLowerCase() });
  if (!user || !(await bcrypt.compare(String(password || ''), user.passwordHash))) return res.status(401).json({ error: 'Wrong username or password' });
  if (user.banned) return res.status(403).json({ error: 'This account is banned' });
  Object.assign(user, { lastIp: ip(req), lastLoginAt: new Date(), lastDevice: device, lastPlatform: platform, lastAppVersion: appVersion, loginCount: user.loginCount + 1 });
  await user.save();
  res.json({ token: sign({ id: user.id, username: user.username, role: 'user' }), user: pub(user) });
}));

// admin credentials come from .env only
router.post('/admin/login', limiter, W(async (req, res) => {
  const { username, password } = req.body || {};
  const a = await Admin.findOne({ username: String(username || '').trim().toLowerCase() });
  if (!a || !(await bcrypt.compare(String(password || ''), a.passwordHash))) {
    return res.status(401).json({ error: 'Wrong admin credentials' });
  }
  res.json({ token: sign({ role: 'admin', username: a.username }, '12h') });
}));

router.get('/config/ice', auth(), (_q, res) => res.json({ iceServers: cfg.ice() }));

router.get('/update/latest', W(async (req, res) => {
  const u = await latestFor(String(req.query.platform || 'all'), String(req.query.version || '0.0.0'));
  res.json(u ? { available: true, version: u.version, url: u.url, mode: u.mode, notes: u.notes, platform: u.platform } : { available: false });
}));

router.get('/admin/overview', A, W(async (_q, res) => res.json({
  online: [...st.online.values()],
  sessions: [...st.sessions.values()].map((s) => ({ token: s.token, host: s.hostName, mode: s.mode, listeners: s.listeners.size, waiting: s.waiting.size, startedAt: s.startedAt })),
  userCount: await User.countDocuments(),
})));
router.get('/admin/users', A, W(async (_q, res) => res.json(await User.find().select('-passwordHash').sort({ createdAt: -1 }).limit(500))));
router.post('/admin/users/:id/ban', A, W(async (req, res) => {
  const u = await User.findById(req.params.id);
  if (!u) return res.status(404).json({ error: 'Not found' });
  u.banned = !u.banned; await u.save();
  if (u.banned) for (const i of st.online.values()) if (i.username === u.username) st.io.sockets.sockets.get(i.socketId)?.disconnect(true);
  res.json({ banned: u.banned });
}));
router.delete('/admin/users/:id', A, W(async (req, res) => { await User.findByIdAndDelete(req.params.id); res.json({ ok: true }); }));
router.post('/admin/kick/:sid', A, (req, res) => { st.io.sockets.sockets.get(req.params.sid)?.disconnect(true); res.json({ ok: true }); });

router.get('/admin/updates', A, W(async (_q, res) => res.json(await AppUpdate.find().sort({ createdAt: -1 }).limit(30))));
router.post('/admin/updates', A, W(async (req, res) => {
  const { version, url, mode, platform, notes } = req.body || {};
  if (!/^\d+(\.\d+){0,2}$/.test(String(version || ''))) return res.status(400).json({ error: 'Version like 1.2.0' });
  if (!/^https?:\/\//i.test(String(url || ''))) return res.status(400).json({ error: 'Link must start with http(s)://' });
  const u = await AppUpdate.create({ version, url, mode: mode === 'force' ? 'force' : 'simple', platform: platform || 'all', notes });
  // push to every connected device right now
  st.io.emit('update:available', { available: true, version: u.version, url: u.url, mode: u.mode, notes: u.notes, platform: u.platform });
  res.json(u);
}));
router.delete('/admin/updates/:id', A, W(async (req, res) => { await AppUpdate.findByIdAndDelete(req.params.id); res.json({ ok: true }); }));

module.exports = router;
