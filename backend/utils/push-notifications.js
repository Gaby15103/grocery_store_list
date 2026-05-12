const { User, Group } = require('../models');
const admin = require('firebase-admin');

async function sendPushToGroup(groupId, senderEmail, data) {
    try {
        const group = await Group.findByPk(groupId, {
            // Sequelize defaults to the capitalized plural of the model name
            include: [{ model: User, as: 'Users' }]
        });

        if (!group || !group.Users) {
            console.log("No group or users found for push notification.");
            return;
        }

        const tokens = group.Users
            .filter(u => u.email !== senderEmail && u.deviceTokens && Object.keys(u.deviceTokens).length > 0)
            .flatMap(u => Object.values(u.deviceTokens)); // Get all tokens for that user

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