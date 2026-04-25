const express = require('express');
const cors = require('cors');
const { sequelize, Group, List, Item, User, UserGroup, Op } = require('./models');

const app = express();
const morgan = require('morgan');
app.use(cors());
app.use(express.json());
app.use(morgan('dev'));
app.use((req, res, next) => {
    console.log(`\n--- [${new Date().toLocaleTimeString()}] ---`);
    console.log(`${req.method} ${req.url}`);

    // Check for email header
    if (req.headers && req.headers['x-user-email']) {
        console.log(`👤 User: ${req.headers['x-user-email']}`);
    }

    // SAFE CHECK: req.body
    if (req.body && Object.keys(req.body).length > 0) {
        console.log('📦 Body:', JSON.stringify(req.body, null, 2));
    }

    // SAFE CHECK: req.params
    if (req.params && Object.keys(req.params).length > 0) {
        console.log('📍 Params:', req.params);
    }

    next();
});

// --- GROUP ROUTES ---

// Get groups ONLY for the authenticated user
app.get('/groups', async (req, res) => {
    const email = req.headers['x-user-email'];
    if (!email) return res.status(400).send("Email header missing");

    try {
        const user = await User.findOne({
            where: { email },
            include: [{ model: Group }]
        });
        if (!user) return res.status(404).send("User not found");
        res.json(user.Groups);
    } catch (err) {
        res.status(500).send(err.message);
    }
});

// Create a group and link it to the owner
app.post('/groups', async (req, res) => {
    const { id, name } = req.body;
    const email = req.headers['x-user-email'];
    if (!email) return res.status(400).send("Email header missing");

    try {
        const user = await User.findOne({ where: { email } });
        if (!user) return res.status(404).json({ error: "User not found" });

        const group = await Group.create({ id, name, ownerId: user.id });

        // Link the creator in the many-to-many table
        await UserGroup.create({
            UserId: user.id,
            GroupId: group.id,
            role: 'owner',
            status: 'accepted'
        });

        res.status(201).json(group);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// --- LIST & ITEM ROUTES ---

app.post('/lists', async (req, res) => {
    const { id, name, GroupId, createdAt } = req.body;

    try {
        const newList = await List.create({
            id,
            name,
            GroupId, // Ensure the casing matches your model (usually GroupId)
            createdAt: createdAt || new DateTime()
        });
        res.status(201).json(newList);
    } catch (error) {
        console.error("❌ List Creation Error:", error.message);
        res.status(500).json({ error: error.message });
    }
});

app.get('/groups/:groupId/lists', async (req, res) => {
    const lists = await List.findAll({
        where: { GroupId: req.params.groupId },
        order: [['createdAt', 'DESC']]
    });
    res.json(lists);
});

app.get('/lists/:listId/items', async (req, res) => {
    try {
        const items = await Item.findAll({
            where: { ListId: req.params.listId }, // Ensure this matches your model's FK
            order: [['createdAt', 'ASC']]
        });
        res.json(items);
    } catch (e) {
        console.error("❌ Error fetching items:", e.message);
        res.status(500).json({ error: e.message });
    }
});

app.post('/items', async (req, res) => {
    const { name, status, listId } = req.body;
    try {
        const item = await Item.create({
            name,
            status,
            ListId: listId // Ensure this matches your association alias
        });
        res.status(201).json(item);
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

app.put('/items/update', async (req, res) => {
    const { name, listId, status } = req.body;

    try {
        const [updatedRows] = await Item.update(
            { status },
            { where: { name, ListId: listId } }
        );

        if (updatedRows === 0) {
            return res.status(404).json({ error: "Item not found in database" });
        }

        res.status(200).json({ message: "Status updated" });
    } catch (e) {
        console.error("❌ Update Error:", e.message);
        res.status(500).json({ error: e.message });
    }
});

app.post('/sync-items', async (req, res) => {
    try {
        const { listId, items } = req.body;
        // Transactional approach is better on Arch/Postgres for data integrity
        await sequelize.transaction(async (t) => {
            await Item.destroy({ where: { ListId: listId } }, { transaction: t });
            await Item.bulkCreate(
                items.map(item => ({ ...item, ListId: listId })),
                { transaction: t }
            );
        });
        res.status(200).json({ message: 'Sync successful' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// --- USER & INVITE ROUTES ---

app.post('/users/register', async (req, res) => {
    try {
        const { firstName, lastName, email, deviceId } = req.body;
        const [user, created] = await User.findOrCreate({
            where: { email },
            defaults: { firstName, lastName, deviceId }
        });
        if (!created && deviceId) {
            await user.update({ deviceId });
        }
        res.status(201).json(user);
    } catch (error) {
        res.status(500).send("Internal Server Error");
    }
});

// Invitation logic
app.post('/groups/:groupId/invite', async (req, res) => {
    const { email } = req.body;
    try {
        const user = await User.findOne({ where: { email } });
        if (!user) return res.status(404).send('User not found');

        await UserGroup.findOrCreate({
            where: { UserId: user.id, GroupId: req.params.groupId },
            defaults: { status: 'pending' }
        });
        res.sendStatus(201);
    } catch (e) {
        res.status(500).send(e.message);
    }
});

app.get('/users/invitations', async (req, res) => {
    const email = req.headers['x-user-email'];

    try {
        const user = await User.findOne({ where: { email } });
        if (!user) return res.status(404).json({ error: "User not found" });

        // Fetch invitations with the Group details
        const invites = await UserGroup.findAll({
            where: { UserId: user.id, status: 'pending' },
            include: [{ model: Group }]
        });

        // Manually fetch owner emails to avoid complex association errors for now
        const formattedInvites = await Promise.all(invites.map(async (invite) => {
            const owner = await User.findByPk(invite.Group.ownerId);
            return {
                groupId: invite.Group.id,
                GroupName: invite.Group.name,
                OwnerEmail: owner ? owner.email : "Unknown Owner"
            };
        }));

        res.json(formattedInvites);
    } catch (e) {
        console.error("❌ Database Error:", e.message);
        res.status(500).json({ error: e.message });
    }
});

app.put('/groups/:groupId/invite/respond', async (req, res) => {
    const email = req.headers['x-user-email'];
    const { status } = req.body; // 'accepted' or 'declined'
    const { groupId } = req.params;

    try {
        const user = await User.findOne({ where: { email } });
        if (!user) return res.status(404).json({ error: "User not found" });

        if (status === 'accepted') {
            await UserGroup.update({ status: 'accepted' }, {
                where: { UserId: user.id, GroupId: groupId }
            });
            res.status(200).json({ message: "Invitation accepted" });
        } else {
            // If declined, we just remove the relationship
            await UserGroup.destroy({
                where: { UserId: user.id, GroupId: groupId, status: 'pending' }
            });
            res.status(200).json({ message: "Invitation declined" });
        }
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Update User Profile (First Name, Last Name, Email)
app.put('/user/profile', async (req, res) => {
    const { firstName, lastName, email } = req.body;
    const currentEmail = req.headers['x-user-email'];

    if (!currentEmail) return res.status(400).json({ error: "Missing current email header" });

    try {
        // 1. Check if the NEW email is already taken by someone else
        if (email !== currentEmail) {
            const existingUser = await User.findOne({ where: { email } });
            if (existingUser) {
                return res.status(409).json({ error: "Email already in use" });
            }
        }

        // 2. Update the user
        const [updatedRows] = await User.update(
            { firstName, lastName, email },
            { where: { email: currentEmail } }
        );

        if (updatedRows === 0) {
            return res.status(404).json({ error: "User not found" });
        }

        res.status(200).json({ message: "Profile updated successfully" });
    } catch (error) {
        console.error("❌ Profile Update Error:", error.message);
        res.status(500).json({ error: error.message });
    }
});

app.post('/user/link', async (req, res) => {
    const { currentDeviceId, targetSyncCode } = req.body;

    try {
        const targetUser = await User.findOne({ where: { deviceId: targetSyncCode } });

        if (!targetUser) {
            return res.status(404).json({ error: "Sync Code not found" });
        }
        res.status(200).json({
            message: "Account linked",
            user: {
                email: targetUser.email,
                firstName: targetUser.firstName,
                lastName: targetUser.lastName
            }
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.get('/users/contacts', async (req, res) => {
    const email = req.headers['x-user-email'];
    if (!email) return res.status(400).send("Email header missing");

    try {
        const user = await User.findOne({ where: { email } });
        if (!user) return res.status(404).send("User not found");

        // 1. Get all GroupIds where this user is a member
        const myUserGroups = await UserGroup.findAll({
            where: { UserId: user.id, status: 'accepted' },
            attributes: ['GroupId'],
            raw: true
        });

        const groupIds = myUserGroups.map(ug => ug.GroupId);
        if (groupIds.length === 0) return res.json([]);

        // 2. Find all OTHER UserIds in those same groups
        const otherUserGroups = await UserGroup.findAll({
            where: {
                GroupId: groupIds,
                status: 'accepted',
                UserId: { [Op.ne]: user.id } // Exclude myself
            },
            attributes: ['UserId'],
            raw: true
        });

        const otherUserIds = [...new Set(otherUserGroups.map(ug => ug.UserId))];
        if (otherUserIds.length === 0) return res.json([]);

        // 3. Fetch the actual User details for those IDs
        const contacts = await User.findAll({
            where: { id: otherUserIds },
            attributes: ['email', 'firstName', 'lastName'],
            raw: true
        });

        res.json(contacts);
    } catch (err) {
        console.error("❌ Contacts Fetch Error:", err);
        res.status(500).json({ error: err.message });
    }
});



const PORT = process.env.PORT || 3000;
// Use alter:true during dev on Arch to stay synced with Flutter model changes
sequelize.sync({ alter: true }).then(() => {
    app.listen(PORT, '0.0.0.0', () => console.log(`🚀 API: http://localhost:${PORT}`));
});