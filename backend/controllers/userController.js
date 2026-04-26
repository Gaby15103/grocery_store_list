const { User, UserGroup, Group, Op } = require('../models');

exports.register = async (req, res) => {
    try {
        const { firstName, lastName, email, deviceId } = req.body;
        const [user, created] = await User.findOrCreate({ where: { email }, defaults: { firstName, lastName, deviceId } });
        if (!created && deviceId) await user.update({ deviceId });
        res.status(201).json(user);
    } catch (error) { res.status(500).send("Internal Server Error"); }
};

exports.getInvitations = async (req, res) => {
    const email = req.headers['x-user-email'];
    try {
        const user = await User.findOne({ where: { email } });
        if (!user) return res.status(404).json({ error: "User not found" });
        const invites = await UserGroup.findAll({ where: { UserId: user.id, status: 'pending' }, include: [{ model: Group }] });
        const formatted = await Promise.all(invites.map(async (inv) => {
            const owner = await User.findByPk(inv.Group.ownerId);
            return { groupId: inv.Group.id, GroupName: inv.Group.name, OwnerEmail: owner?.email || "Unknown" };
        }));
        res.json(formatted);
    } catch (e) { res.status(500).json({ error: e.message }); }
};

exports.updateProfile = async (req, res) => {
    const { firstName, lastName, email } = req.body;
    const currentEmail = req.headers['x-user-email'];
    try {
        if (email !== currentEmail) {
            const exists = await User.findOne({ where: { email } });
            if (exists) return res.status(409).json({ error: "Email in use" });
        }
        await User.update({ firstName, lastName, email }, { where: { email: currentEmail } });
        res.status(200).json({ message: "Profile updated" });
    } catch (error) { res.status(500).json({ error: error.message }); }
};

exports.linkAccount = async (req, res) => {
    const { targetSyncCode } = req.body;
    try {
        const target = await User.findOne({ where: { deviceId: targetSyncCode } });
        if (!target) return res.status(404).json({ error: "Code not found" });
        res.json({ user: { email: target.email, firstName: target.firstName, lastName: target.lastName } });
    } catch (error) { res.status(500).json({ error: error.message }); }
};

exports.getContacts = async (req, res) => {
    const email = req.headers['x-user-email'];
    try {
        const user = await User.findOne({ where: { email } });
        const myGroups = await UserGroup.findAll({ where: { UserId: user.id, status: 'accepted' }, attributes: ['GroupId'], raw: true });
        const groupIds = myGroups.map(ug => ug.GroupId);
        if (groupIds.length === 0) return res.json([]);
        const otherUsers = await UserGroup.findAll({ where: { GroupId: groupIds, status: 'accepted', UserId: { [Op.ne]: user.id } }, attributes: ['UserId'], raw: true });
        const ids = [...new Set(otherUsers.map(u => u.UserId))];
        const contacts = await User.findAll({ where: { id: ids }, attributes: ['email', 'firstName', 'lastName'], raw: true });
        res.json(contacts);
    } catch (err) { res.status(500).json({ error: err.message }); }
};