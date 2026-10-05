const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

admin.initializeApp();
const db = admin.firestore();

/**
 * Configure SMTP transporter using environment variables or Firebase config.
 * For production: Use SendGrid, Postmark, or Gmail App Password.
 */
// Credentials come ONLY from configuration — never hardcoded. If they are not
// configured, the email is queued in /mail for the "Trigger Email" extension.
const smtpUser = process.env.EMAIL_USER || functions.config().email?.user;
const smtpPass = process.env.EMAIL_PASS || functions.config().email?.pass;
const transporter = smtpUser && smtpPass
  ? nodemailer.createTransport({ service: 'gmail', auth: { user: smtpUser, pass: smtpPass } })
  : null;

/**
 * CCE 106 - Single-Branch Booking Approval Trigger
 * Listens to updates on `/bookings/{bookingId}`.
 * When an Admin approves a booking (status changes to 'approved'), this function:
 * 1. Retrieves customer information (email, name).
 * 2. Compiles a formatted HTML Digital Receipt.
 * 3. Sends confirmation email to the customer.
 * 4. Logs delivery status in Firestore.
 */
exports.onBookingApprovedSendReceipt = functions.firestore
  .document('bookings/{bookingId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const bookingId = context.params.bookingId;

    const oldStatus = (before.status || '').toLowerCase().trim();
    const newStatus = (after.status || '').toLowerCase().trim();

    // Trigger strictly when status transitions from 'pending' -> 'approved'
    if (oldStatus === newStatus || newStatus !== 'approved') {
      return null;
    }

    functions.logger.info(`Booking ${bookingId} approved. Preparing automated receipt email...`);

    try {
      // 1. Resolve Customer Email & Name
      let customerEmail = after.customerEmail;
      let customerName = after.customerName || 'Valued Pet Parent';

      if (!customerEmail && after.custID) {
        // Query customers collection
        const custDoc = await db.collection('customers').doc(after.custID).get();
        if (custDoc.exists) {
          const custData = custDoc.data();
          customerEmail = custData.email;
          customerName = `${custData.cusFName || ''} ${custData.cusLName || ''}`.trim() || customerName;
        }
      }

      if (!customerEmail && after.userID) {
        // Fallback to users collection
        const userDoc = await db.collection('users').doc(after.userID).get();
        if (userDoc.exists) {
          customerEmail = userDoc.data().email;
        }
      }

      // No fake fallback address: if the customer has no email, skip sending.
      if (!customerEmail) {
        functions.logger.warn(`No email found for customer ID ${after.custID}. Receipt not sent.`);
        return null;
      }

      // Format Dates
      const checkInStr = after.checkInDate?.toDate ? after.checkInDate.toDate().toISOString().split('T')[0] : 'Scheduled Date';
      const checkOutStr = after.checkOutDate?.toDate ? after.checkOutDate.toDate().toISOString().split('T')[0] : 'Scheduled Date';
      const totalAmount = Number(after.totalAmount || 0).toFixed(2);

      // 2. Build HTML Digital Receipt Template (Davao City Branch Single-Branch MVP)
      const htmlContent = `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f8fafc; margin: 0; padding: 20px; }
            .container { max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 12px; border: 1px solid #e2e8f0; overflow: hidden; }
            .header { background-color: #0284c7; color: #ffffff; padding: 24px; text-align: center; }
            .header h1 { margin: 0; font-size: 22px; font-weight: 700; letter-spacing: 0.5px; }
            .header p { margin: 6px 0 0; font-size: 13px; opacity: 0.9; }
            .content { padding: 24px; color: #1e293b; line-height: 1.5; }
            .badge { display: inline-block; padding: 4px 12px; background-color: #dcfce7; color: #15803d; border-radius: 9999px; font-weight: 700; font-size: 12px; margin-bottom: 12px; }
            .details-box { background-color: #f1f5f9; border-radius: 8px; padding: 16px; margin: 20px 0; }
            .details-row { display: flex; justify-content: space-between; padding: 6px 0; border-bottom: 1px solid #e2e8f0; font-size: 14px; }
            .details-row:last-child { border-bottom: none; font-weight: bold; font-size: 16px; color: #0284c7; padding-top: 10px; }
            .qr-notice { background-color: #eff6ff; border-left: 4px solid #0284c7; padding: 14px; margin-top: 20px; border-radius: 4px; font-size: 13px; color: #1e40af; }
            .footer { background-color: #f8fafc; padding: 16px; text-align: center; font-size: 12px; color: #64748b; border-top: 1px solid #e2e8f0; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1>Pet Hotel Booking Confirmation</h1>
              <p>Davao City Branch • Matina Highway, Davao City</p>
            </div>
            <div class="content">
              <span class="badge">&#10003; RESERVATION APPROVED</span>
              <p>Dear <strong>${customerName}</strong>,</p>
              <p>Your pet hotel reservation has been officially <strong>reviewed and approved</strong> by our Davao City administration team!</p>
              
              <div class="details-box">
                <div class="details-row"><span>Booking Reference:</span><span><strong>${bookingId}</strong></span></div>
                <div class="details-row"><span>Branch:</span><span>Matina Central, Davao City</span></div>
                <div class="details-row"><span>Room Assigned:</span><span>${after.roomID || 'Standard Suite'}</span></div>
                <div class="details-row"><span>Check-In Date:</span><span>${checkInStr} (${after.checkInTimeSlot || 'Morning'})</span></div>
                <div class="details-row"><span>Check-Out Date:</span><span>${checkOutStr}</span></div>
                <div class="details-row"><span>Total Amount Settled:</span><span>PHP ${totalAmount}</span></div>
              </div>

              <div class="qr-notice">
                <strong>Express Check-In QR Pass Unlocked:</strong><br/>
                Your digital pass is now active inside the Pet Hotel mobile app. Simply present your pass at the front counter upon arrival in Matina, Davao City for instant scanning and check-in.
              </div>

              <p style="margin-top: 24px;">Need to adjust your stay? Please contact our Davao City desk at (082) 298-PETS.</p>
            </div>
            <div class="footer">
              &copy; 2026 Davao Pet Hotel Booking System (CCE 106 Project). All rights reserved.
            </div>
          </div>
        </body>
        </html>
      `;

      // 3. Dispatch Email
      const mailOptions = {
        from: `"Davao Pet Hotel Booking" <${smtpUser || 'noreply@pethotel.local'}>`,
        to: customerEmail,
        subject: `[Approved] Booking Confirmation & Receipt (Ref: ${bookingId}) - Davao Pet Hotel`,
        html: htmlContent,
      };

      // Send ONE email: direct SMTP when configured, otherwise (or on SMTP
      // failure) queue it in /mail for the "Trigger Email" extension.
      let sent = false;
      if (transporter) {
        try {
          await transporter.sendMail(mailOptions);
          sent = true;
          functions.logger.info(`Receipt email successfully sent to ${customerEmail} for booking ${bookingId}.`);
        } catch (mailError) {
          functions.logger.warn(`SMTP error: ${mailError.message}. Queuing in /mail instead.`);
        }
      }

      // 4. Fallback: record to Firestore `mail` collection (Trigger Email extension)
      if (!sent) await db.collection('mail').add({
        to: customerEmail,
        bookingId: bookingId,
        type: 'BOOKING_APPROVAL_RECEIPT',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        message: {
          subject: `[Approved] Booking Confirmation & Receipt (Ref: ${bookingId}) - Davao Pet Hotel`,
          html: htmlContent,
        },
      });

      // 5. Update booking document with email receipt confirmation timestamp
      await change.after.ref.update({
        receiptDispatchedAt: admin.firestore.FieldValue.serverTimestamp(),
        receiptRecipient: customerEmail,
      });

      return null;
    } catch (error) {
      functions.logger.error(`Error processing booking approval trigger for ${bookingId}:`, error);
      return null;
    }
  });
