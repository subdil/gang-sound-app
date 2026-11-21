const { Server } = require('socket.io');
const crypto = require('crypto');
const { verify } = require('./auth');
const { User, SessionLog } = require('./models');
const { latestFor } = require('./updates');
const st = require('./state');

const ALPH = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const MODES = ['others', 'all', 'select']; // others only | all devices | host picks
const newToken = () => { let t; do { t = Array.from({ length: 6 }, () => ALPH[crypto.randomInt(ALPH.length)]).join(''); } while (st.sessions.has(t)); return t; };

module.exports = function (server, cfg) {
  const io = new Server(server, { cors: { origin: cfg.cors === '*' ? true : cfg.cors.split(',') } });
  st.io = io;
  const sk = (id) => io.sockets.sockets.get(id);

  io.use(async (s, next) => {
    try {
      const a = s.handshake.auth || {};
      const p = verify(a.token);
      if (p.role !== 'user') return next(new Error('unauthorized'));
      const u = await User.findById(p.id);
      if (!u || u.banned) return next(new Error('banned'));
      const platform = String(a.platform || '?').slice(0, 20), appVersion = String(a.appVersion || '0.0.0').slice(0, 12);
      const f = await latestFor(platform, appVersion);
      if (f && f.mode === 'force') return next(new Error('update_required')); // force update is enforced server side too
      s.data.user = p;
      s.data.info = {
        socketId: s.id, username: p.username, device: String(a.device || 'unknown').slice(0, 40), platform, appVersion,
        ip: String(s.handshake.headers['x-forwarded-for'] || s.handshake.address || '').split(',')[0], connectedAt: Date.now(), session: null,
      };
      next();
    } catch { next(new Error('unauthorized')); }
  });

  const brief = (s) => ({ id: s.id, username: s.data.user.username, device: s.data.info.device, platform: s.data.info.platform });
  const push = (S) => io.to(S.host).emit('session:state', { token: S.token, mode: S.mode, listeners: [...S.listeners.values()], waiting: [...S.waiting.values()] });
  const approve = (S, s) => {
    S.waiting.delete(s.id); S.listeners.set(s.id, brief(s)); S.total++;
    s.data.info.session = S.token;
    s.emit('session:approved', { token: S.token, hostId: S.host });
    io.to(S.host).emit('listener:ready', { id: s.id });
  };
  const leaveSession = (s) => {
    const S = st.sessions.get(s.data.joined);
    s.data.joined = null; s.data.info.session = null;
    if (!S) return;
    S.waiting.delete(s.id);
    if (S.listeners.delete(s.id)) io.to(S.host).emit('listener:gone', { id: s.id });
    push(S);
  };
  const endSession = (S, why = 'Host ended the session') => {
    for (const id of [...S.listeners.keys(), ...S.waiting.keys()]) {
      const x = sk(id); if (x) { x.data.joined = null; x.data.info.session = null; x.emit('session:ended', { why }); }
    }
    st.sessions.delete(S.token);
    const h = sk(S.host); if (h) { h.data.hosting = null; h.data.info.session = null; }
    SessionLog.updateOne({ token: S.token, endedAt: null }, { endedAt: new Date(), listenerCount: S.total }).catch(() => {});
  };
  const mine = (s) => st.sessions.get(s.data.hosting);

  io.on('connection', (s) => {
    st.online.set(s.id, s.data.info);

    s.on('session:create', (d = {}, cb = () => {}) => {
      if (s.data.hosting) return cb({ ok: false, error: 'You are already broadcasting' });
      leaveSession(s);
      const S = { token: newToken(), host: s.id, hostName: s.data.user.username, mode: MODES.includes(d.mode) ? d.mode : 'others', listeners: new Map(), waiting: new Map(), total: 0, startedAt: Date.now() };
      st.sessions.set(S.token, S); s.data.hosting = S.token; s.data.info.session = S.token;
      SessionLog.create({ token: S.token, host: S.hostName, mode: S.mode }).catch(() => {});
      cb({ ok: true, token: S.token }); push(S);
    });

    s.on('session:join', (d = {}, cb = () => {}) => {
      const S = st.sessions.get(String(d.token || '').toUpperCase().trim());
      if (!S) return cb({ ok: false, error: 'Invalid token' });
      if (S.host === s.id) return cb({ ok: false, error: 'That is your own token' });
      leaveSession(s); s.data.joined = S.token;
      if (S.mode === 'select') { S.waiting.set(s.id, brief(s)); push(S); return cb({ ok: true, status: 'waiting' }); }
      approve(S, s); push(S); cb({ ok: true, status: 'approved' });
    });

    s.on('session:decide', ({ id, allow } = {}) => {
      const S = mine(s), t = sk(id);
      if (!S || !t || !S.waiting.has(id)) return;
      if (allow) approve(S, t); else { S.waiting.delete(id); t.data.joined = null; t.emit('session:denied'); }
      push(S);
    });
    s.on('session:kick', ({ id } = {}) => {
      const S = mine(s); if (!S || !S.listeners.has(id)) return;
      S.listeners.delete(id); io.to(S.host).emit('listener:gone', { id });
      const t = sk(id); if (t) { t.data.joined = null; t.data.info.session = null; t.emit('session:kicked'); }
      push(S);
    });
    s.on('session:setMode', ({ mode } = {}) => {
      const S = mine(s); if (!S || !MODES.includes(mode)) return;
      S.mode = mode;
      if (mode !== 'select') for (const id of [...S.waiting.keys()]) { const t = sk(id); t ? approve(S, t) : S.waiting.delete(id); }
      push(S);
    });
    s.on('session:end', () => { const S = mine(s); if (S) endSession(S); });
    s.on('session:leave', () => leaveSession(s));

    // WebRTC signalling, only host <-> listener inside the same session
    s.on('signal', ({ to, data } = {}) => {
      const S = st.sessions.get(s.data.hosting || s.data.joined); if (!S) return;
      const ok = (s.id === S.host && S.listeners.has(to)) || (S.listeners.has(s.id) && to === S.host);
      if (ok) io.to(to).emit('signal', { from: s.id, data });
    });

    s.on('disconnect', () => {
      st.online.delete(s.id);
      const S = mine(s); if (S) endSession(S, 'Host disconnected');
      leaveSession(s);
    });
  });
};
