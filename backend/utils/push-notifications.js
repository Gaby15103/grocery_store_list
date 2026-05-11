const admin = require('../config/firebase-init'); // The key file we talked about

export const sendPushToGroup = async (groupId, senderEmail, dataPayload) => {
    try {
        const users = await User.findAll({
            include: [{ model: Group, where: { id: groupId } }],
            where: { email: { [Op.ne]: senderEmail } }
        });


        const allTokens = users.flatMap(u => Object.values(u.deviceTokens || {}));

        if (allTokens.length > 0) {
            const message = {
                data: dataPayload,
                tokens: [...new Set(allTokens)],
            };

            const response = await admin.messaging().sendEachForMulticast(message);
            console.log(`FCM: Successfully sent ${response.successCount} messages.`);
        }
    } catch (err) {
        console.error("FCM Multi-blast error:", err);
    }
};