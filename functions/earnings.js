// File: functions/earnings.js
const functions = require("firebase-functions");
const admin = require("firebase-admin");

const db = admin.firestore();

// Get earnings history for a user
exports.getEarningsHistory = functions.https.onCall(async (data, context) => {
  // Check if user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated to access earnings history",
    );
  }

  try {
    const userId = context.auth.uid;

    // Get transactions for the user
    const transactionsQuery = await db.collection("transactions")
        .where("userId", "==", userId)
        .orderBy("createdAt", "desc")
        .limit(50) // Limit to most recent 50 transactions
        .get();

    const transactions = transactionsQuery.docs.map((doc) => {
      const data = doc.data();
      return {
        id: doc.id,
        amount: data.amount,
        type: data.type,
        description: data.description,
        createdAt: data.createdAt.toDate(),
      };
    });

    return {transactions};
  } catch (error) {
    console.error("Error getting earnings history:", error);
    throw new functions.https.HttpsError("internal", "Error retrieving earnings history");
  }
});

// Add bonus earnings (from ads, etc.)
exports.addBonus = functions.https.onCall(async (data, context) => {
  // Check if user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated to add bonus",
    );
  }

  // Validate parameters
  if (!data.amount || typeof data.amount !== "number" || data.amount <= 0) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Amount must be a positive number",
    );
  }

  if (!data.type || typeof data.type !== "string") {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Bonus type must be specified",
    );
  }

  try {
    const userId = context.auth.uid;
    const amount = Math.min(data.amount, 0.50); // Cap bonus at $0.50 to prevent abuse
    const type = data.type;
    const description = data.description || "Bonus earnings";

    // Update user's balance
    await db.collection("users").doc(userId).update({
      availableBalance: admin.firestore.FieldValue.increment(amount),
      totalEarnings: admin.firestore.FieldValue.increment(amount),
      lastActive: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Log the transaction
    await db.collection("transactions").add({
      userId: userId,
      amount: amount,
      type: type,
      description: description,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {success: true, amount};
  } catch (error) {
    console.error("Error adding bonus:", error);
    throw new functions.https.HttpsError("internal", "Error adding bonus earnings");
  }
});
