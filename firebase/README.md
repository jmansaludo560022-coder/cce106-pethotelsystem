# Firebase Backend & Automated Receipt Triggers
## CCE 106 - Davao Pet Hotel Booking System (Single-Branch MVP)

This directory contains the Cloud Functions and Firebase configuration for the Davao City Single-Branch Pet Hotel Booking System.

### 1. Booking Approval & Automated Digital Receipt Lifecycle
* **Trigger Event**: Admin reviews a pending booking and clicks **"Approve & Send Receipt"** in the Flutter Admin Portal.
* **Firestore Transition**: Document `/bookings/{bookingId}` updates from `status: 'pending'` to `status: 'approved'`.
* **Execution**:
  1. `onBookingApprovedSendReceipt` Cloud Function intercepts the update.
  2. Resolves customer email from `after.customerEmail` or `/customers/{custID}` document.
  3. Renders a formatted HTML Digital Receipt detailing:
     - Booking Reference ID
     - Single-Branch Facility Address: Matina, Davao City
     - Assigned Room & Check-In/Out Dates
     - Itemized Total Amount in Philippine Pesos (PHP)
     - Notification confirming that their **Digital QR Pass** is unlocked in the app.
  4. Dispatches the email via SMTP (`nodemailer`) or records it into the `/mail` collection for the official Firebase **Trigger Email** extension.

### 2. Dual Delivery Mechanism Supported
1. **Direct Cloud Function SMTP**:
   Deploy functions via `firebase deploy --only functions`.
   Set environment variables:
   ```bash
   firebase functions:config:set email.user="your-hotel-email@gmail.com" email.pass="app-password"
   ```
2. **Firebase Extension ("Trigger Email from Firestore")**:
   When installed in Firebase Console, any document written to the `/mail` collection is automatically processed by SendGrid, Mailgun, or SMTP without writing extra server code.

### 3. Verification & Testing
* Submit a booking from the mobile app -> Verify document has `status: 'pending'`.
* Open Flutter Admin Portal -> Go to **"Booking Approvals"** -> Click **"Approve & Send Receipt"**.
* Verify status transitions to `'approved'`, Digital QR pass unlocks in customer app, and receipt entry is generated in `/mail`.
