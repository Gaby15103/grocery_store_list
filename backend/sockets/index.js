const { Server } = require('socket.io');
// Assuming you have a pool or database service to query your groups
const pool = require('../config/db.js');

const initSockets = (server) => {
    const io = new Server(server, {
        cors: { origin: "*" }
    });

    io.on('connection', async (socket) => {
        const userEmail = socket.handshake.headers['x-user-email'];
        console.log(`🔌 New Connection: ${socket.id} (${userEmail})`);

        if (userEmail) {
            try {
                // 1. Query all groups this user belongs to
                // Adjust the SQL to match your schema (PostgreSQL example)
                const result = await pool.query(
                    'SELECT group_id FROM group_members WHERE user_email = $1',
                    [userEmail]
                );

                // 2. Automatically join every group room
                result.rows.forEach(row => {
                    const roomName = row.group_id.toString();
                    socket.join(roomName);
                    console.log(`✅ Auto-joined: ${userEmail} -> Room ${roomName}`);
                });
            } catch (err) {
                console.error("❌ Error auto-joining rooms:", err);
            }
        }

        socket.on('disconnect', () => {
            console.log(`🔌 Disconnected: ${socket.id}`);
        });
    });

    return io;
};

module.exports = { initSockets };