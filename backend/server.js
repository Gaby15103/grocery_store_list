const express = require('express');
const cors = require('cors');
const http = require('http');
const morgan = require('morgan');
const path = require('path');
const { sequelize } = require('./models');
const { initSockets } = require('./sockets');

const app = express();
const server = http.createServer(app);
const io = initSockets(server);

app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(morgan('dev'));

app.use('/uploads', express.static(path.join(__dirname, 'public/uploads')));

// Logger Middleware (Customized from your old one)
app.use((req, res, next) => {
    console.log(`\n--- [${new Date().toLocaleTimeString()}] ${req.method} ${req.url} ---`);
    if (req.headers['x-user-email']) console.log(`👤 User: ${req.headers['x-user-email']}`);
    if (req.body && Object.keys(req.body).length > 0) console.log('📦 Body:', JSON.stringify(req.body, null, 2));
    next();
});

// Pass IO to controllers
app.use((req, res, next) => {
    req.io = io;
    next();
});
app.use('/groups', require('./routes/groupRoutes'));
app.use('/items', require('./routes/itemRoutes'));
app.use('/lists', require('./routes/listRoutes'));
app.use('/users', require('./routes/userRoutes'));
app.use('/upload', require('./routes/uploadRoutes'));

const PORT = process.env.PORT || 3000;

sequelize.sync({ alter: true }).then(() => {
    server.listen(PORT, '0.0.0.0', () => {
        console.log(`🚀 API & WebSockets active: http://localhost:${PORT}`);
    });
}).catch(err => console.error("❌ Sync Error:", err));