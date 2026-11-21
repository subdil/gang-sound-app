// live (in-memory) state shared by REST + sockets
module.exports = { io: null, online: new Map(), sessions: new Map() };
