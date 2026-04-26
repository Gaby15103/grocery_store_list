const { List, Item, sequelize } = require('../models');

exports.createList = async (req, res) => {
    const { id, name, GroupId, createdAt } = req.body;
    try {
        const newList = await List.create({ id, name, GroupId, createdAt: createdAt || new Date() });
        res.status(201).json(newList);
    } catch (error) { res.status(500).json({ error: error.message }); }
};

exports.getListsByGroup = async (req, res) => {
    const lists = await List.findAll({ where: { GroupId: req.params.groupId }, order: [['createdAt', 'DESC']] });
    res.json(lists);
};

exports.getListItems = async (req, res) => {
    try {
        const items = await Item.findAll({ where: { ListId: req.params.listId }, order: [['createdAt', 'ASC']] });
        res.json(items);
    } catch (e) { res.status(500).json({ error: e.message }); }
};

exports.createItem = async (req, res) => {
    const { name, status, listId, groupId } = req.body;
    try {
        const item = await Item.create({ name, status, ListId: listId });
        if (groupId) {
            req.io.to(groupId).emit('item_added', {
                ...item.toJSON(),
                listId: item.ListId
            });
        }
        res.status(201).json(item);
    } catch (e) { res.status(500).json({ error: e.message }); }
};

exports.updateItem = async (req, res) => {
    const { name, listId, status, groupId } = req.body;
    try {
        const [updatedRows] = await Item.update({ status }, { where: { name, ListId: listId } });
        if (updatedRows === 0) return res.status(404).json({ error: "Item not found" });
        if (groupId) req.io.to(groupId).emit('item_updated', { name, status, listId });
        res.status(200).json({ message: "Status updated" });
    } catch (e) { res.status(500).json({ error: e.message }); }
};

exports.syncItems = async (req, res) => {
    const { listId, items, groupId } = req.body;
    try {
        await sequelize.transaction(async (t) => {
            await Item.destroy({ where: { ListId: listId } }, { transaction: t });
            await Item.bulkCreate(items.map(item => ({ ...item, ListId: listId })), { transaction: t });
        });
        if (groupId) req.io.to(groupId).emit('list_synced', { listId });
        res.status(200).json({ message: 'Sync successful' });
    } catch (error) { res.status(500).json({ error: error.message }); }
};