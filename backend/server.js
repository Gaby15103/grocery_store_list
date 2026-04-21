const express = require('express');
const cors = require('cors');
const { sequelize, Group, List, Item } = require('./models');

const app = express();
app.use(cors());
app.use(express.json());

// Get all lists for a specific group
app.get('/groups/:groupId/lists', async (req, res) => {
    const lists = await List.findAll({ where: { GroupId: req.params.groupId } });
    res.json(lists);
});

app.post('/items', async (req, res) => {
    const { name, status, listId, createdAt } = req.body;
    const item = await Item.create({
        name,
        status,
        ListId: listId, // Sequelize expects ListId based on associations
        createdAt
    });
    res.status(201).json(item);
});

app.put('/items/update', async (req, res) => {
    const { name, listId, status } = req.body;
    await Item.update({ status }, {
        where: { name, ListId: listId }
    });
    res.sendStatus(200);
});

app.post('/groups', async (req, res) => {
    const group = await Group.create(req.body);
    res.status(201).json(group);
});
// backend/server.js
app.post('/lists', async (req, res) => {
    try {
        const { id, name, GroupId, createdAt } = req.body;

        // Check if group exists, if not create a default one to avoid FK errors
        await Group.findOrCreate({ where: { id: GroupId }, defaults: { name: 'Default Group' } });

        const list = await List.create({
            id,
            name,
            GroupId,
            createdAt
        });

        res.status(201).json(list);
    } catch (error) {
        console.error('Sequelize Error:', error);
        res.status(500).json({ error: error.message });
    }
});

// Sync items
app.post('/sync', async (req, res) => {
    // Logic for bulk syncing from Hive to Postgres will go here
    res.sendStatus(200);
});

app.post('/sync-items', async (req, res) => {
    try {
        const { listId, items } = req.body;

        // Optional: Clear existing items for this list to avoid duplicates during sync
        await Item.destroy({ where: { ListId: listId } });

        // Bulk insert the new items
        await Item.bulkCreate(items.map(item => ({
            ...item,
            ListId: listId // Mapping the Flutter listId to Sequelize foreign key
        })));

        res.status(200).json({ message: 'Sync successful' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

const PORT = process.env.PORT || 3000;
sequelize.sync({ alter: true }).then(() => {
    app.listen(PORT, () => console.log(`🚀 API running on http://localhost:${PORT}`));
});