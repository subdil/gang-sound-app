const jwt = require('jsonwebtoken'), crypto = require('crypto'), cfg = require('./config');
const sign = (p, exp = '30d') => jwt.sign(p, cfg.jwt, { expiresIn: exp });
const verify = (t) => jwt.verify(t, cfg.jwt);
const h = (v) => crypto.createHash('sha256').update(String(v)).digest();
const safeEq = (a, b) => crypto.timingSafeEqual(h(a), h(b));
const auth = (role) => (req, res, next) => {
  try {
    const p = verify((req.headers.authorization || '').replace('Bearer ', ''));
    if (role && p.role !== role) return res.status(403).json({ error: 'Forbidden' });
    req.user = p; next();
  } catch { res.status(401).json({ error: 'Unauthorized' }); }
};
module.exports = { sign, verify, safeEq, auth };
