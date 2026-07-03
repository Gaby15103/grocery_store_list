const {List, Item, sequelize, User, Group, Type} = require('../models');
const {sendPushToGroup} = require('../utils/push-notifications');


exports.createList = async (req, res) => {
    const {name, GroupId} = req.body;
    try {
        const newList = await List.create({name, GroupId, createdAt: new Date()});
        res.status(201).json(newList);
    } catch (error) {
        res.status(500).json({error: error.message});
    }
};

exports.getListsByGroup = async (req, res) => {
    const lists = await List.findAll({where: {GroupId: req.params.groupId}, order: [['createdAt', 'DESC']]});
    res.json(lists);
};

exports.deleteList = async (req, res) => {
    const {listId} = req.params;
    const email = req.headers['x-user-email'];
    if (!email) return res.status(400).send("Email header missing");

    try {
        const list = await List.findOne({where: {id: listId}});
        if (!list) return res.status(404).send("List not found");

        const user = await User.findOne({where: {email}});
        if (!user) return res.status(404).send("User not found");
        const group = await Group.findOne({where: {id: list.GroupId}});
        if (group.ownerId !== user.id) {
            return res.status(403).send("Only the group owner can delete lists.");
        }

        await List.destroy({where: {id: list.id}});

        req.io.to(list.groupId).emit('notification', {
            type: 'list_deleted',
            listId: list.id,
            groupId: list.groupId,
            title: 'List Removed',
            message: `${user.firstName || 'A user'} deleted the list "${list.name}".`,
            data: {name: list.name, id: list.id}
        });
        res.status(204).send();
    } catch (err) {
        console.error(err);
        res.status(500).send(err.message);
    }
};

exports.getTypes = async (req, res) => {
    try {
        const types = await Type.findAll();
        res.status(200).json(types);
    } catch (e) {
        res.status(500).json({error: e.message});
    }
}

exports.getListItems = async (req, res) => {
    try {
        const items = await Item.findAll({
            where: {ListId: req.params.listId},
            include: [{model: Type, attributes: ['id', 'name']}],
            order: [['createdAt', 'ASC']]
        });
        res.json(items);
    } catch (e) {
        res.status(500).json({error: e.message});
    }
};

exports.createItem = async (req, res) => {
    const {name, status, listId, groupId, note, imagePath, typeId} = req.body;
    const senderEmail = req.headers['x-user-email'];

    try {
        let item = await Item.create({name, status, ListId: listId, note, imagePath, TypeId: typeId});

        item = await Item.findByPk(item.id, {include: [Type]});

        if (groupId) {
            const user = await User.findOne({where: {email: senderEmail}});
            const senderName = user ? user.firstName : 'Someone';

            req.io.to(groupId).emit('item_added', {...item.toJSON(), listId: item.ListId});

            await sendPushToGroup(groupId, senderEmail, {
                type: 'item_added',
                itemName: name,
                listId: listId.toString(),
                senderName: senderName
            });
        }
        res.status(201).json(item);
    } catch (e) {
        res.status(500).json({error: e.message});
    }
};

exports.deleteItem = async (req, res) => {
    const {itemId} = req.params;
    const {name, listId, groupId} = req.body;
    const senderEmail = req.headers['x-user-email'];
    try {
        await Item.destroy({where: {id: itemId}});
        if (groupId) {
            req.io.to(groupId).emit('item_deleted', {id: itemId, name, listId});
            sendPushToGroup(groupId, senderEmail, {
                type: 'item_deleted',
                itemName: name,
                listId: listId.toString()
            });
        }
        res.status(200).json({message: "Deleted"});
    } catch (e) {
        res.status(500).json({error: e.message});
    }
};

exports.updateItem = async (req, res) => {
    const {id, name, listId, status, groupId, note, imagePath, typeId} = req.body;
    const senderEmail = req.headers['x-user-email'];
    try {
        const [updatedRows] = await Item.update(
            {name, status, note, imagePath, TypeId: typeId},
            {where: {id}}
        );

        if (updatedRows > 0 && groupId) {
            const updatedItem = await Item.findByPk(id, {include: [Type]});

            req.io.to(groupId.toString()).emit('item_updated', {
                id,
                name,
                listId,
                status,
                note,
                imagePath,
                Type: updatedItem.Type
            });

            if (status === 'bought') {
                await sendPushToGroup(groupId, senderEmail, {
                    type: 'item_updated',
                    itemName: name,
                    listId: listId.toString(),
                    status: 'bought'
                });
            }
        }
        res.status(200).json({message: "Updated"});
    } catch (e) {
        res.status(500).json({error: e.message});
    }
};

exports.syncItems = async (req, res) => {
    const {listId, items, groupId} = req.body;
    try {
        await sequelize.transaction(async (t) => {
            await Item.destroy({where: {ListId: listId}}, {transaction: t});
            await Item.bulkCreate(items.map(item => ({...item, ListId: listId})), {transaction: t});
        });
        if (groupId) req.io.to(groupId).emit('list_synced', {listId});
        res.status(200).json({message: 'Sync successful'});
    } catch (error) {
        res.status(500).json({error: error.message});
    }
};

exports.archiveAndCarryOver = async (req, res) => {
    const {listId} = req.params;
    const {newName} = req.body;
    const t = await sequelize.transaction();

    try {
        const oldList = await List.findByPk(listId, {transaction: t});
        if (!oldList) throw new Error('List not found');

        await oldList.update({isArchived: true}, {transaction: t});

        const newListId = `list_${Date.now()}`;
        const newList = await List.create({
            id: newListId,
            name: newName || `${oldList.name} (Cont.)`,
            GroupId: oldList.GroupId,
            isArchived: false
        }, {transaction: t});

        await Item.update(
            {ListId: newListId},
            {
                where: {
                    ListId: listId,
                    status: 'pending'
                },
                transaction: t
            }
        );

        await t.commit();
        res.status(201).json(newList);

    } catch (error) {
        await t.rollback();
        res.status(500).json({error: error.message});
    }
};