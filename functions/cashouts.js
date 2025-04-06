// File: functions/cashouts.js
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

const db = admin.firestore();

// App configuration
const CONFIG = {
  minCashoutAmount: 10.0, // $10 minimum cashout
  paypalEmail: "payouts@steprewards.com",
  supportEmail: "support@steprewards.com",
};

// Create transporter for emails
const transporter = nodemailer.createTransport({
  // Configure with your email provider details
  service: "gmail",
  auth: {
    user: CONFIG.supportEmail,
    pass: functions.config().email.password,
  },
});

// Process new cashout requests
exports.processCashoutRequest = functions.firestore
    .document("cashouts/{cashoutId}")
    .onCreate(async (snapshot, context) => {
      const cashoutData = snapshot.data();

      try {
      // Validate cashout request
        if (cashoutData.amount < CONFIG.minCashoutAmount) {
          await snapshot.ref.update({
            status: "rejected",
            rejectionReason: `Minimum cashout amount is $${CONFIG.minCashoutAmount}`,
            processedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          return null;
        }

        // Get user data
        const userDoc = await db.collection("users").doc(cashoutData.userId).get();

        if (!userDoc.exists) {
          await snapshot.ref.update({
            status: "rejected",
            rejectionReason: "User not found",
            processedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          return null;
        }

        const userData = userDoc.data();

        // Check if user has premium status
        const isPremium = userData.isPremium || false;

        // Notify admin via email
        const mailOptions = {
          from: CONFIG.supportEmail,
          to: CONFIG.paypalEmail,
          subject: `New Cashout Request: $${cashoutData.amount}`,
          html: `
          <h2>New Cashout Request</h2>
          <p><strong>User:</strong> ${userData.displayName} (${userData.email})</p>
          <p><strong>Amount:</strong> $${cashoutData.amount}</p>
          <p><strong>PayPal Email:</strong> ${cashoutData.paypalEmail}</p>
          <p><strong>Status:</strong> ${isPremium ? "Premium User" : "Free User"}</p>
          <p><strong>Requested:</strong> ${cashoutData.createdAt.toDate().toLocaleString()}</p>
          <p>Please process this request in the admin dashboard.</p>
        `,
        };

        await transporter.sendMail(mailOptions);

        // Auto-approve for premium users (still requires admin to actually send payment)
        if (isPremium) {
          await snapshot.ref.update({
            status: "approved",
            processedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          // Notify user
          const userMailOptions = {
            from: CONFIG.supportEmail,
            to: userData.email,
            subject: "Your Cashout Request Has Been Approved",
            html: `
            <h2>Cashout Request Approved</h2>
            <p>Hello ${userData.displayName},</p>
            <p>Your cashout request for $${cashoutData.amount} has been approved and is being processed.</p>
            <p>You should receive payment to your PayPal account (${cashoutData.paypalEmail}) within 24 hours.</p>
            <p>Thank you for using Step Rewards!</p>
          `,
          };

          await transporter.sendMail(userMailOptions);
        }

        return null;
      } catch (error) {
        console.error("Error processing cashout request:", error);
        return null;
      }
    });

// API endpoint to update cashout status (for admin use)
exports.updateCashoutStatus = functions.https.onCall(async (data, context) => {
  // Check if user is authenticated and is an admin
  if (!context.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated to update cashout status",
    );
  }

  try {
    // Check if user is admin
    const adminDoc = await db.collection("admins").doc(context.auth.uid).get();

    if (!adminDoc.exists) {
      throw new functions.https.HttpsError(
          "permission-denied",
          "User must be an admin to update cashout status",
      );
    }

    // Validate parameters
    if (!data.cashoutId) {
      throw new functions.https.HttpsError(
          "invalid-argument",
          "Cashout ID must be specified",
      );
    }

    if (!data.status || !["approved", "rejected", "completed"].includes(data.status)) {
      throw new functions.https.HttpsError(
          "invalid-argument",
          "Status must be one of: approved, rejected, completed",
      );
    }

    // Get cashout data
    const cashoutDoc = await db.collection("cashouts").doc(data.cashoutId).get();

    if (!cashoutDoc.exists) {
      throw new functions.https.HttpsError(
          "not-found",
          "Cashout request not found",
      );
    }

    const cashoutData = cashoutDoc.data();

    // Update cashout status
    const updates = {
      status: data.status,
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
      processedBy: context.auth.uid,
    };

    if (data.status === "rejected" && data.rejectionReason) {
      updates.rejectionReason = data.rejectionReason;
    }

    await cashoutDoc.ref.update(updates);

    // If marked as completed, log the transaction
    if (data.status === "completed") {
      await db.collection("transactions").add({
        userId: cashoutData.userId,
        amount: -cashoutData.amount, // Negative amount for cashout
        type: "cashout",
        description: `Cashout to PayPal (${cashoutData.paypalEmail})`,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Update user data
      await db.collection("users").doc(cashoutData.userId).update({
        pendingCashout: admin.firestore.FieldValue.increment(-cashoutData.amount),
        lastActive: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Notify user
      const userDoc = await db.collection("users").doc(cashoutData.userId).get();
      const userData = userDoc.data();

      const mailOptions = {
        from: CONFIG.supportEmail,
        to: userData.email,
        subject: "Your Cashout Has Been Completed",
        html: `
          <h2>Cashout Completed</h2>
          <p>Hello ${userData.displayName},</p>
          <p>Your cashout of $${cashoutData.amount} has been completed and sent to your PayPal account (${cashoutData.paypalEmail}).</p>
          <p>Thank you for using Step Rewards!</p>
        `,
      };

      await transporter.sendMail(mailOptions);
    } else if (data.status === "rejected") {
      // Return funds to user's available balance
      await db.collection("users").doc(cashoutData.userId).update({
        availableBalance: admin.firestore.FieldValue.increment(cashoutData.amount),
        pendingCashout: admin.firestore.FieldValue.increment(-cashoutData.amount),
        lastActive: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Notify user of rejection
      const userDoc = await db.collection("users").doc(cashoutData.userId).get();
      const userData = userDoc.data();

      const mailOptions = {
        from: CONFIG.supportEmail,
        to: userData.email,
        subject: "Your Cashout Request Has Been Rejected",
        html: `
          <h2>Cashout Request Rejected</h2>
          <p>Hello ${userData.displayName},</p>
          <p>Unfortunately, your cashout request for $${cashoutData.amount} has been rejected.</p>
          <p><strong>Reason:</strong> ${updates.rejectionReason || "No reason provided"}</p>
          <p>The funds have been returned to your available balance. Please reach out to support if you have any questions.</p>
        `,
      };

      await transporter.sendMail(mailOptions);
    }

    return {success: true};
  } catch (error) {
    console.error("Error updating cashout status:", error);
    throw new functions.https.HttpsError("internal", "Error updating cashout status");
  }
});
