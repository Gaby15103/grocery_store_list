const { User, UserGroup, Group, Op } = require('../models');

exports.register = async (req, res) => {
    try {
        const { firstName, lastName, email, deviceId } = req.body;

        const existingUser = await User.findOne({ where: { email } });
        if (existingUser) {
            return res.status(409).json({ error: "User already exists. Use Sync Code to link." });
        }

        const newUser = await User.create({
            email,
            firstName,
            lastName,
            authorizedDevices: [deviceId] // First device is automatically authorized
        });

        res.status(201).json(newUser);
    } catch (error) {
        res.status(500).json({ error: "Internal Server Error" });
    }
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
    const deviceId = req.headers['x-device-id'];

    if (!deviceId) {
        return res.status(403).json({ error: "Device identification missing" });
    }

    try {
        const user = await User.findOne({ where: { email: currentEmail } });
        if (!user) return res.status(404).json({ error: "User not found" });

        const isAuthorized = user.authorizedDevices && user.authorizedDevices.includes(deviceId);

        if (!isAuthorized) {
            return res.status(401).json({ error: "Unauthorized device." });
        }

        if (email !== currentEmail) {
            const exists = await User.findOne({ where: { email } });
            if (exists) return res.status(409).json({ error: "Email in use" });
        }

        await user.update({ firstName, lastName, email });

        res.status(200).json({ message: "Profile updated" });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

exports.getUser = async (req, res) => {
    const email = req.headers['x-user-email'];
    const deviceId = req.headers['x-device-id'];

    try {
        const user = await User.findOne({
            where: { email },
            attributes: ['firstName', 'lastName', 'email', 'authorizedDevices']
        });

        if (!user) return res.status(404).json({ error: "User not found" });

        const userData = user.toJSON();
        // Add a flag so the Flutter app knows if it needs to prompt for verification
        userData.isCurrentDeviceVerified = user.authorizedDevices.includes(deviceId);

        res.status(200).json(userData);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

exports.getUser = async (req, res) => {
    const email = req.headers['x-user-email'];
    const deviceId = req.headers['x-device-id'];

    try {
        const user = await User.findOne({
            where: { email },
            attributes: ['firstName', 'lastName', 'email', 'authorizedDevices']
        });

        if (!user) return res.status(404).json({ error: "User not found" });

        const userData = user.toJSON();
        userData.isCurrentDeviceVerified = user.authorizedDevices.includes(deviceId);

        res.status(200).json(userData);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

exports.getUserProfile = async (req, res) => {
    const targetEmail = req.params.email;

    try {
        const user = await User.findOne({
            where: { email: targetEmail },
            attributes: ['firstName', 'lastName', 'email']
        });

        if (!user) return res.status(404).json({ error: "User not found" });

        res.status(200).json(user);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

exports.linkAccount = async (req, res) => {
    const { currentDeviceId, targetSyncCode } = req.body;

    try {
        const user = await User.findOne({
            where: {
                authorizedDevices: { [Op.contains]: [targetSyncCode] }
            }
        });
        if (!targetSyncCode || !user) {
            return res.status(404).json({ error: "Invalid Sync Code." });
        }
        let devices = [...user.authorizedDevices];
        if (!devices.includes(currentDeviceId)) {
            devices.push(currentDeviceId);
            user.authorizedDevices = devices;
            await user.save();
        }
        res.status(200).json({
            user: {
                email: user.email,
                firstName: user.firstName,
                lastName: user.lastName
            }
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
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