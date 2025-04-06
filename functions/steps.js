// File: functions/steps.js
const functions = require("firebase-functions");
const admin = require("firebase-admin");

const db = admin.firestore();

// App configuration
const CONFIG = {
  stepsPerDollar: 10000, // $1 per 10,000 steps
  maxDailyStepsFree: 20000, // 20k steps cap for free users
  maxDailyStepsPremium: 40000, // 40k steps cap for premium users
  maxDailyEarningsFree: 2.0, // $2/day for free users
  maxDailyEarningsPremium: 4.0, // $4/day for premium users
};

// Validate and calculate earnings for step updates
exports.validateSteps = functions.firestore
    .document("steps/{stepId}")
    .onWrite(async (change, context) => {
    // If document was deleted, do nothing
      if (!change.after.exists) return null;

      const stepData = change.after.data();
      const previousData = change.before.exists ? change.before.data() : null;

      // If steps were already validated or no change in step count, do nothing
      if (
        stepData.isValidated ||
      (previousData && stepData.stepCount === previousData.stepCount)
      ) {
        return null;
      }

      try {
      // Get user data to check premium status
        const userDoc = await db.collection("users").doc(stepData.userId).get();

        if (!userDoc.exists) {
          console.error("User not found:", stepData.userId);
          return null;
        }

        const userData = userDoc.data();
        const isPremium = userData.isPremium || false;

        // Apply anti-cheat cap
        const maxSteps = isPremium ? CONFIG.maxDailyStepsPremium : CONFIG.maxDailyStepsFree;
        const cappedSteps = Math.min(stepData.stepCount, maxSteps);

        // Calculate earnings based on capped steps and multiplier
        let earnings = (cappedSteps / CONFIG.stepsPerDollar) * stepData.multiplier;

        // Apply daily earnings cap
        const maxEarnings = isPremium ? CONFIG.maxDailyEarningsPremium : CONFIG.maxDailyEarningsFree;
        earnings = Math.min(earnings, maxEarnings);

        // Round to 2 decimal places
        earnings = Math.round(earnings * 100) / 100;

        // Update steps document
        await change.after.ref.update({
          stepCount: cappedSteps, // Apply the cap
          earnings: earnings,
          isValidated: true,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Calculate incremental earnings (if this is an update)
        let incrementalEarnings = earnings;
        if (previousData && previousData.earnings) {
          incrementalEarnings = earnings - previousData.earnings;
        }

        // Update user's earnings and lifetime steps
        const stepIncrement = previousData ? (cappedSteps - previousData.stepCount) : cappedSteps;

        if (incrementalEarnings > 0) {
          await userDoc.ref.update({
            availableBalance: admin.firestore.FieldValue.increment(incrementalEarnings),
            totalEarnings: admin.firestore.FieldValue.increment(incrementalEarnings),
            lifetimeSteps: admin.firestore.FieldValue.increment(Math.max(0, stepIncrement)),
            lastActive: admin.firestore.FieldValue.serverTimestamp(),
          });

          // Log the transaction
          await db.collection("transactions").add({
            userId: stepData.userId,
            amount: incrementalEarnings,
            type: "steps_earnings",
            description: `Earnings from ${cappedSteps} steps`,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        // Update tournament status if needed
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        const activeTournamentsQuery = await db.collection("tournaments")
            .where("isActive", "==", true)
            .where("startDate", "<=", admin.firestore.Timestamp.fromDate(today))
            .where("endDate", ">=", admin.firestore.Timestamp.fromDate(today))
            .get();

        if (!activeTournamentsQuery.empty) {
          const batch = db.batch();

          for (const tournamentDoc of activeTournamentsQuery.docs) {
          // Update or create participant entry
            const participantRef = db.collection("tournament_participants")
                .where("tournamentId", "==", tournamentDoc.id)
                .where("userId", "==", stepData.userId)
                .limit(1);

            const participantQuery = await participantRef.get();

            if (participantQuery.empty) {
            // Create new participant entry
              batch.set(db.collection("tournament_participants").doc(), {
                tournamentId: tournamentDoc.id,
                userId: stepData.userId,
                displayName: userData.displayName || "",
                photoUrl: userData.photoUrl || "",
                stepCount: cappedSteps,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              });
            } else {
            // Update existing entry with increased step count
              const participantDoc = participantQuery.docs[0];
              const participantData = participantDoc.data();

              batch.update(participantDoc.ref, {
                stepCount: Math.max(participantData.stepCount, cappedSteps),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              });
            }
          }

          await batch.commit();
        }

        return null;
      } catch (error) {
        console.error("Error validating steps:", error);
        return null;
      }
    });

// API endpoint to get step stats for a user
exports.getStepStats = functions.https.onCall(async (data, context) => {
  // Check if user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated to access step stats",
    );
  }

  try {
    const userId = context.auth.uid;

    // Get steps for the last 30 days
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const stepsQuery = await db.collection("steps")
        .where("userId", "==", userId)
        .where("date", ">=", admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
        .orderBy("date", "asc")
        .get();

    const stepsData = stepsQuery.docs.map((doc) => {
      const data = doc.data();
      return {
        id: doc.id,
        date: data.date.toDate(),
        stepCount: data.stepCount,
        earnings: data.earnings,
      };
    });

    // Calculate stats
    let totalSteps = 0;
    let totalEarnings = 0;
    let bestDay = {date: null, steps: 0};

    stepsData.forEach((day) => {
      totalSteps += day.stepCount;
      totalEarnings += day.earnings;

      if (day.stepCount > bestDay.steps) {
        bestDay = {date: day.date, steps: day.stepCount};
      }
    });

    const avgSteps = stepsData.length > 0 ? totalSteps / stepsData.length : 0;

    return {
      dailyData: stepsData,
      stats: {
        totalSteps,
        totalEarnings,
        avgSteps,
        bestDay,
      },
    };
  } catch (error) {
    console.error("Error getting step stats:", error);
    throw new functions.https.HttpsError("internal", "Error retrieving step statistics");
  }
});
