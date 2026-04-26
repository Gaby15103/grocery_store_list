const { Server } = require('socket.io');

const initSockets = (server) => {
    const io = new Server(server, {
        cors: { origin: "*" }
    });

    io.on('connection', (socket) => {
        console.log(`🔌 New Connection: ${socket.id}`);

        socket.on('join_group', (groupId) => {
            socket.join(groupId);
            console.log(`👤 Socket ${socket.id} joined Group Room: ${groupId}`);
        });

        socket.on('disconnect', () => {
            console.log(`🔌 Disconnected: ${socket.id}`);
        });
    });

    return io;
};

module.exports = { initSockets };