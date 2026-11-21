const m = require('mongoose');

const User = m.model('User', new m.Schema({
  username: { type: String, unique: true, required: true, lowercase: true, trim: true },
  displayName: String,
  email: { type: String, trim: true, lowercase: true },
  phone: String,
  passwordHash: { type: String, required: true },
  banned: { type: Boolean, default: false },
  loginCount: { type: Number, default: 0 },
  lastLoginAt: Date, lastIp: String, lastDevice: String, lastPlatform: String, lastAppVersion: String,
}, { timestamps: true }));

const Admin = m.model('Admin', new m.Schema({
  username: { type: String, unique: true, required: true, lowercase: true, trim: true },
  passwordHash: { type: String, required: true },
}, { timestamps: true }));

const AppUpdate = m.model('AppUpdate', new m.Schema({
  version: { type: String, required: true },
  url: { type: String, required: true },
  mode: { type: String, enum: ['force', 'simple'], default: 'simple' },
  platform: { type: String, default: 'all' },
  notes: String,
}, { timestamps: true }));

const SessionLog = m.model('SessionLog', new m.Schema({
  token: String, host: String, mode: String,
  listenerCount: { type: Number, default: 0 },
  endedAt: Date,
}, { timestamps: true }));

module.exports = { User, Admin, AppUpdate, SessionLog };