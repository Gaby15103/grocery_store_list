const { List, Item, sequelize, User, Group} = require('../models');

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

exports.deleteList = async (req, res) => {
    const { listId } = req.params;
    const email = req.headers['x-user-email'];

    if (!email) return res.status(400).send("Email header missing");

    try {
        const list = await List.findOne({ where: { id: listId } });
        if (!list) return res.status(404).send("List not found");

        const user = await User.findOne({ where: { email } });
        if (!user) return res.status(404).send("User not found");
        const group = await Group.findOne({ where: { id: list.GroupId } });
        if (group.ownerId !== user.id) {
            return res.status(403).send("Only the group owner can delete lists.");
        }

        await List.destroy({ where: { id: list.id } });

        req.io.to(list.groupId).emit('notification', {
            type: 'list_deleted',
            listId: list.id,
            groupId: list.groupId,
            title: 'List Removed',
            message: `${user.firstName || 'A user'} deleted the list "${list.name}".`,
            data: { name: list.name, id: list.id }
        });
        res.status(204).send();
    } catch (err) {
        console.error(err);
        res.status(500).send(err.message);
    }
};

exports.getListItems = async (req, res) => {
    try {
        const items = await Item.findAll({ where: { ListId: req.params.listId }, order: [['createdAt', 'ASC']] });
        res.json(items);
    } catch (e) { res.status(500).json({ error: e.message }); }
};

exports.createItem = async (req, res) => {
    const { name, status, listId, groupId, note, imagePath } = req.body;
    try {
        const item = await Item.create({ name, status, ListId: listId, note, imagePath });
        if (groupId) {
            req.io.to(groupId).emit('item_added', {
                ...item.toJSON(),
                listId: item.ListId
            });
            let user = await User.findOne({ email: req.headers['x-user-email'] });
            req.io.to(groupId).emit('notification', {
                type: 'item_added',
                listId: listId,
                title: 'New Item Added ➕',
                message: `${user.firstName || 'Someone'} added ${name} to the list.`,
                data: { name, listId }
            });
        }
        res.status(201).json(item);
    } catch (e) { res.status(500).json({ error: e.message }); }
};
exports.deleteItem = async (req, res) => {
    const { name, listId, groupId } = req.body;
    try {
        await Item.destroy({ where: { name, ListId: listId } });
        if (groupId) {
            req.io.to(groupId).emit('item_deleted', { name, listId });
            let user = await User.findOne({ email: req.headers['x-user-email'] });
            req.io.to(groupId).emit('notification', {
                type: 'item_deleted',
                listId: listId,
                title: 'New Item Deleted',
                message: `${user.firstName || 'Someone'} deleted ${name} from the list.`,
                data: { name, listId }
            });
        }
        res.status(200).json({ message: "Deleted" });
    } catch (e) { res.status(500).json({ error: e.message }); }
};

exports.updateItem = async (req, res) => {
    const { name, listId, status, groupId, note, imagePath  } = req.body;
    try {
        const [updatedRows] = await Item.update(
            { name, status, note, imagePath },
            { where: { name, ListId: listId } }
        );

        if (updatedRows > 0 && groupId) {
            req.io.to(groupId).emit('item_updated', {
                name: name,
                listId: listId,
                status: status
            });
            if (status === 'bought') {
                let user = await User.findOne({ email: req.headers['x-user-email'] });
                req.io.to(groupId).emit('notification', {
                    type: 'item_updated',
                    listId: listId,
                    title: 'Item Purchased 🛒',
                    message: `${user.firstName || 'Someone'} just bought ${name}!`,
                    data: { name, listId }
                });
            }
        }
        res.status(200).json({ message: "Updated" });
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