const nodemailer = require('nodemailer');


const smtpHost = process.env.SMTP_HOST || 'localhost';
const smtpPort = parseInt(process.env.SMTP_PORT || '1025', 10);

const config = {
    host: smtpHost,
    port: smtpPort,
    secure: smtpPort === 465,
};

if (process.env.SMTP_USER) {
    config.auth = {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS
    };
}

const transporter = nodemailer.createTransport(config);

/**
 * Sends a permanent device sync/backup key to the user
 */
exports.sendSyncKeyEmail = async (user, syncKey) => {
    const fromAddress = process.env.MAIL_FROM_ADDRESS || 'no-reply@homerecipes.com';

    const htmlBody = `
        <html><body style="font-family: sans-serif; color: #18181b;">
        <h3>Hello ${user.firstName},</h3>
        <p>Welcome to <b>HomeRecipes</b>! Your grocery app account has been initialized.</p>
        <p>Your permanent device synchronization and backup key is:</p>
        <div style="margin: 24px 0; background-color: #f4f4f5; padding: 16px; border-radius: 8px; font-family: monospace; font-size: 16px; font-weight: bold; border: 1px solid #e4e4e7; display: inline-block;">
            ${syncKey}
        </div>
        <p>Use this key on your other devices to pair them securely to your shared lists.</p>
        <p>Thanks,<br/>The HomeRecipes Team</p>
        </body></html>
    `;

    const textBody = `Hello ${user.firstName},\n\nWelcome to HomeRecipes!\n\nYour permanent device synchronization and backup key is:\n\n${syncKey}\n\nUse this key on your other devices to pair them to your shared lists.\n\nThanks,\nThe HomeRecipes Team`;

    try {
        await transporter.sendMail({
            from: `"HomeRecipes" <${fromAddress}>`,
            to: user.email,
            subject: 'HomeRecipes - Your Synchronization Key',
            text: textBody,
            html: htmlBody
        });
    } catch (error) {
        console.error("❌ Email transmission failed:", error);
        throw new Error(`Email service failure: ${error.message}`);
    }
};