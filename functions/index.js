const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

const db = admin.firestore();

// Import modular cloud functions
const authFunctions = require("./auth")(admin, functions);
const stepsFunctions = require("./steps")(admin, functions);
const earningsFunctions = require("./earnings")(admin, functions);
const cashoutFunctions = require("./cashouts")(admin, functions);
const tournamentFunctions = require("./tournaments")(admin, functions);

// Export individual cloud functions
exports.createUserRecord = authFunctions.createUserRecord;
exports.checkReferralCompletion = authFunctions.checkReferralCompletion;
exports.steps = stepsFunctions;
exports.earnings = earningsFunctions;
exports.cashouts = cashoutFunctions;
exports.tournaments = tournamentFunctions;

// Example scheduled function
exports.dailyMidnightReset = functions.pubsub
  .schedule("0 0 * * *")
  .timeZone("America/New_York")
  .onRun(async (context) => {
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    yesterday.setHours(0, 0, 0, 0);

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    try {
      const usersSnapshot = await db.collection("users").get();
      const batch = db.batch();

      for (const userDoc of usersSnapshot.docs) {
        const userId = userDoc.id;

        const yesterdayStepsQuery = await db.collection("steps")
          .where("userId", "==", userId)
          .where("date", "==", admin.firestore.Timestamp.fromDate(yesterday))
          .limit(1)
          .get();

        const userData = userDoc.data();
        let currentStreak = userData.currentStreak || 0;

        if (!yesterdayStepsQuery.empty) {
          const stepsData = yesterdayStepsQuery.docs[0].data();

          if (stepsData.stepCount >= 1000) {
            currentStreak += 1;
            if (currentStreak > 7) {
              currentStreak = 7;
            }
          } else {
            currentStreak = 0;
          }
        } else {
          currentStreak = 0;
        }

        batch.update(userDoc.ref, {
          currentStreak: currentStreak,
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        });

        const todayStepsDocRef = db.collection("steps").doc();
        batch.set(todayStepsDocRef, {
          userId: userId,
          date: admin.firestore.Timestamp.fromDate(today),
          stepCount: 0,
          earnings: 0,
          multiplier: 1.0 + (currentStreak * 0.1),
          isValidated: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      console.log(`Processed ${usersSnapshot.size} users for streak updates`);
      return null;
    } catch (error) {
      console.error("Error processing daily reset:", error);
      return null;
    }
  });
