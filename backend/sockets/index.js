const { Server } = require('socket.io');
const { User, Group, UserGroup } = require('./../models'); // Import your models

const initSockets = (server) => {
    const io = new Server(server, {
        cors: { origin: "*" }
    });

    io.on('connection', async (socket) => {
        const userEmail = socket.handshake.auth.email || socket.handshake.headers['x-user-email'];

        if (!userEmail) {
            console.log(`⚠️ Connection rejected: No email provided (Socket: ${socket.id})`);
            return socket.disconnect();
        }

        console.log(`🔌 New Connection: ${userEmail}`);

        try {
            const user = await User.findOne({
                where: { email: userEmail },
                include: [{
                    model: Group,
                    attributes: ['id'],
                    through: { where: { status: 'accepted' } }
                }]
            });

            if (user && user.Groups) {
                user.Groups.forEach(group => {
                    socket.join(group.id);
                    console.log(`✅ ${userEmail} auto-joined Room: ${group.id}`);
                });
            }
        } catch (err) {
            console.error("❌ Error during auto-join logic:", err);
        }

        socket.on('disconnect', () => {
            console.log(`🔌 Disconnected: ${userEmail}`);
        });
    });

    return io;
};

module.exports = { initSockets };