const { User, Group, UserGroup } = require('../models');

exports.getGroups = async (req, res) => {
    const email = req.headers['x-user-email'];
    if (!email) return res.status(400).send("Email header missing");
    try {
        const user = await User.findOne({ where: { email }, include: [{ model: Group }] });
        if (!user) return res.status(404).send("User not found");
        res.json(user.Groups);
    } catch (err) { res.status(500).send(err.message); }
};

exports.createGroup = async (req, res) => {
    const { id, name } = req.body;
    const email = req.headers['x-user-email'];
    if (!email) return res.status(400).send("Email header missing");
    try {
        const user = await User.findOne({ where: { email } });
        if (!user) return res.status(404).json({ error: "User not found" });
        const group = await Group.create({ id, name, ownerId: user.id });
        await UserGroup.create({ UserId: user.id, GroupId: group.id, role: 'owner', status: 'accepted' });
        res.status(201).json(group);
    } catch (error) { res.status(500).json({ error: error.message }); }
};

exports.inviteUser = async (req, res) => {
    const { email } = req.body;
    try {
        const user = await User.findOne({ where: { email } });
        if (!user) return res.status(404).send('User not found');
        await UserGroup.findOrCreate({
            where: { UserId: user.id, GroupId: req.params.groupId },
            defaults: { status: 'pending' }
        });
        res.sendStatus(201);
    } catch (e) { res.status(500).send(e.message); }
};

exports.respondToInvite = async (req, res) => {
    const email = req.headers['x-user-email'];
    const { status } = req.body;
    const { groupId } = req.params;
    try {
        const user = await User.findOne({ where: { email } });
        if (!user) return res.status(404).json({ error: "User not found" });
        if (status === 'accepted') {
            await UserGroup.update({ status: 'accepted' }, { where: { UserId: user.id, GroupId: groupId } });
            res.status(200).json({ message: "Invitation accepted" });
        } else {
            await UserGroup.destroy({ where: { UserId: user.id, GroupId: groupId, status: 'pending' } });
            res.status(200).json({ message: "Invitation declined" });
        }
    } catch (error) { res.status(500).json({ error: error.message }); }
};