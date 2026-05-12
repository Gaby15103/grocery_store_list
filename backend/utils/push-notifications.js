const { User, Group } = require('../models');
const admin = require('firebase-admin');

async function sendPushToGroup(groupId, senderEmail, data) {
    try {
        const group = await Group.findByPk(groupId, {
            include: [{ model: User, as: 'users' }]
        });

        if (!group) return;

        const tokens = group.users
            .filter(u => u.email !== senderEmail && u.fcmToken)
            .map(u => u.fcmToken);

        if (tokens.length === 0) return;

        const message = {
            data: data,
            tokens: tokens,
        };

        const response = await admin.messaging().sendEachForMulticast(message);
        console.log(`Successfully sent ${response.successCount} notifications`);
    } catch (error) {
        console.error('Error sending push notification:', error);
    }
}

module.exports = { sendPushToGroup };