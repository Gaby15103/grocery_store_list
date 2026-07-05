const nodemailer = require('nodemailer');


const smtpHost = process.env.SMTP_HOST || 'localhost';
const smtpPort = parseInt(process.env.SMTP_PORT || '1025', 10);

const config = {
    host: smtpHost,
    port: smtpPort,
    secure: smtpPort === 465,
    tls: {
        rejectUnauthorized: false
    }
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
exports.sendSyncKeyEmail = async (user, syncKey, message = null) => {
    const fromAddress = process.env.MAIL_FROM_ADDRESS || 'no-reply@grocery-master.com';

    const htmlBody = `
            <html>
            <body style="font-family: sans-serif; color: #18181b; line-height: 1.5;">
                <h3>Bonjour ${user.firstName},</h3>
                <p>Bienvenue sur <b>Grocery Master</b>! Votre compte d'application de courses a été initialisé.</p>
                
                ${message && message.trim() ? `
                <div style="margin: 16px 0; padding: 12px 16px; border-left: 4px solid #2563eb; backgroundColor: #eff6ff; color: #1e40af; font-style: italic;">
                    "${message.trim()}"
                </div>
                ` : ''}
            
                <p>Votre clé de synchronisation et de sauvegarde permanente est:</p>
                <div style="margin: 24px 0; background-color: #f4f4f5; padding: 16px; border-radius: 8px; font-family: monospace; font-size: 16px; font-weight: bold; border: 1px solid #e4e4e7; display: inline-block; word-break: break-all;">
                    ${syncKey}
                </div>
                <p>Utilisez cette clé sur vos autres appareils pour les connecter en toute sécurité à vos listes partagées.</p>
                
                <p>Merci,<br/>L'équipe Grocery Master</p>
            </body>
            </html>
            `;

    const textBody = `Hello ${user.firstName},\n\nWelcome to Grocery Master!\n\nYour permanent device synchronization and backup key is:\n\n${syncKey}\n\nUse this key on your other devices to pair them to your shared lists.\n\nThanks,\nThe HomeRecipes Team`;

    try {
        await transporter.sendMail({
            from: `"Grocery Master" <${fromAddress}>`,
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