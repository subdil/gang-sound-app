const { AppUpdate } = require('./models');
const cmp = (a, b) => {
  const x = String(a).split('.').map(Number), y = String(b).split('.').map(Number);
  for (let i = 0; i < 3; i++) { const d = (x[i] || 0) - (y[i] || 0); if (d) return d > 0 ? 1 : -1; }
  return 0;
};
// newest pushed update for this platform, only if the client is older than it
async function latestFor(platform, version) {
  const u = await AppUpdate.findOne({ platform: { $in: ['all', platform] } }).sort({ createdAt: -1 });
  return !u || cmp(version, u.version) >= 0 ? null : u;
}
module.exports = { cmp, latestFor };
