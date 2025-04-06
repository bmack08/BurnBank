// File: functions/tournaments.js
const functions = require("firebase-functions");
const admin = require("firebase-admin");

const db = admin.firestore();

// Create a new tournament (admin only)
exports.createTournament = functions.https.onCall(async (data, context) => {
  // Check if user is authenticated and is an admin
  if (!context.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated to create a tournament",
    );
  }

  try {
    // Check if user is admin
    const adminDoc = await db.collection("admins").doc(context.auth.uid).get();

    if (!adminDoc.exists) {
      throw new functions.https.HttpsError(
          "permission-denied",
          "User must be an admin to create a tournament",
      );
    }

    // Validate required fields
    if (!data.name || !data.startDate || !data.endDate || !data.prizePool) {
      throw new functions.https.HttpsError(
          "invalid-argument",
          "Missing required tournament fields",
      );
    }

    // Create tournament
    const tournamentData = {
      name: data.name,
      description: data.description || "",
      startDate: admin.firestore.Timestamp.fromDate(new Date(data.startDate)),
      endDate: admin.firestore.Timestamp.fromDate(new Date(data.endDate)),
      prizePool: data.prizePool,
      prizes: data.prizes || {},
      participantsCount: 0,
      topParticipants: [],
      isActive: data.isActive !== undefined ? data.isActive : true,
      isPremiumOnly: data.isPremiumOnly || false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    const tournamentRef = await db.collection("tournaments").add(tournamentData);

    return {success: true, tournamentId: tournamentRef.id};
  } catch (error) {
    console.error("Error creating tournament:", error);
    throw new functions.https.HttpsError("internal", "Error creating tournament");
  }
});

// Update tournament leaderboard (scheduled)
exports.updateTournamentLeaderboards = functions.pubsub
    .schedule("every 1 hours")
    .onRun(async (context) => {
      try {
        const now = new Date();

        // Get active tournaments
        const tournamentsQuery = await db.collection("tournaments")
            .where("isActive", "==", true)
            .where("startDate", "<=", admin.firestore.Timestamp.fromDate(now))
            .where("endDate", ">=", admin.firestore.Timestamp.fromDate(now))
            .get();

        if (tournamentsQuery.empty) {
          console.log("No active tournaments found");
          return null;
        }

        const batch = db.batch();

        for (const tournamentDoc of tournamentsQuery.docs) {
          const tournamentId = tournamentDoc.id;

          // Get top participants
          const participantsQuery = await db.collection("tournament_participants")
              .where("tournamentId", "==", tournamentId)
              .orderBy("stepCount", "desc")
              .limit(10) // Get top 10 participants
              .get();

          if (participantsQuery.empty) {
            console.log(`No participants found for tournament ${tournamentId}`);
            continue;
          }

          // Build top participants array with rankings
          const topParticipants = [];
          let rank = 1;

          participantsQuery.forEach((doc) => {
            const data = doc.data();
            topParticipants.push({
              userId: data.userId,
              displayName: data.displayName,
              photoUrl: data.photoUrl || "",
              stepCount: data.stepCount,
              rank: rank,
            });
            rank++;
          });

          // Update tournament with new participant count and top participants
          batch.update(tournamentDoc.ref, {
            participantsCount: participantsQuery.size,
            topParticipants: topParticipants,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        await batch.commit();
        console.log(`Updated ${tournamentsQuery.size} tournament leaderboards`);

        return null;
      } catch (error) {
        console.error("Error updating tournament leaderboards:", error);
        return null;
      }
    });

// End tournament and distribute prizes
exports.endTournament = functions.pubsub
    .schedule("every 1 hours")
    .onRun(async (context) => {
      try {
        const now = new Date();

        // Get tournaments that just ended (within the last hour)
        const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);

        const tournamentsQuery = await db.collection("tournaments")
            .where("isActive", "==", true)
            .where("endDate", ">=", admin.firestore.Timestamp.fromDate(oneHourAgo))
            .where("endDate", "<=", admin.firestore.Timestamp.fromDate(now))
            .get();

        if (tournamentsQuery.empty) {
          console.log("No tournaments ending now");
          return null;
        }

        for (const tournamentDoc of tournamentsQuery.docs) {
          const tournamentId = tournamentDoc.id;
          const tournamentData = tournamentDoc.data();

          // Get final participants ranking
          const participantsQuery = await db.collection("tournament_participants")
              .where("tournamentId", "==", tournamentId)
              .orderBy("stepCount", "desc")
              .get();

          if (participantsQuery.empty) {
            console.log(`No participants found for tournament ${tournamentId}`);

            // Mark tournament as inactive with no winners
            await tournamentDoc.ref.update({
              isActive: false,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            continue;
          }

          // Process winners and distribute prizes
          const batch = db.batch();
          let rank = 1;
          const winners = [];
          const finalParticipants = [];

          for (const participantDoc of participantsQuery.docs) {
            const participantData = participantDoc.data();

            // Add to final participants list
            finalParticipants.push({
              userId: participantData.userId,
              displayName: participantData.displayName,
              photoUrl: participantData.photoUrl || "",
              stepCount: participantData.stepCount,
              rank: rank,
            });

            // Check if participant won a prize
            const prizeKey = rank.toString();
            if (tournamentData.prizes && tournamentData.prizes[prizeKey]) {
              const prizeAmount = tournamentData.prizes[prizeKey];

              // Add prize winner
              winners.push({
                userId: participantData.userId,
                displayName: participantData.displayName,
                rank: rank,
                prizeAmount: prizeAmount,
              });

              // Add prize to user's balance
              const userRef = db.collection("users").doc(participantData.userId);
              batch.update(userRef, {
                availableBalance: admin.firestore.FieldValue.increment(prizeAmount),
                totalEarnings: admin.firestore.FieldValue.increment(prizeAmount),
                lastActive: admin.firestore.FieldValue.serverTimestamp(),
              });

              // Log the transaction
              const transactionRef = db.collection("transactions").doc();
              batch.set(transactionRef, {
                userId: participantData.userId,
                amount: prizeAmount,
                type: "tournament_prize",
                description: `Prize for ${tournamentData.name} (Rank: ${rank})`,
                tournamentId: tournamentId,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
              });
            }

            rank++;
          }

          // Update tournament as ended with winners
          batch.update(tournamentDoc.ref, {
            isActive: false,
            topParticipants: finalParticipants.slice(0, 10), // Store top 10
            winners: winners,
            participantsCount: participantsQuery.size,
            completedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          // Commit all changes
          await batch.commit();

          console.log(`Ended tournament ${tournamentId} with ${winners.length} winners`);
        }

        return null;
      } catch (error) {
        console.error("Error ending tournaments:", error);
        return null;
      }
    });

// Join a tournament
exports.joinTournament = functions.https.onCall(async (data, context) => {
  // Check if user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated to join a tournament",
    );
  }

  try {
    const userId = context.auth.uid;

    // Validate parameters
    if (!data.tournamentId) {
      throw new functions.https.HttpsError(
          "invalid-argument",
          "Tournament ID must be specified",
      );
    }

    // Get tournament data
    const tournamentDoc = await db.collection("tournaments").doc(data.tournamentId).get();

    if (!tournamentDoc.exists) {
      throw new functions.https.HttpsError(
          "not-found",
          "Tournament not found",
      );
    }

    const tournamentData = tournamentDoc.data();

    // Check if tournament is active
    if (!tournamentData.isActive) {
      throw new functions.https.HttpsError(
          "failed-precondition",
          "Tournament is not active",
      );
    }

    // Check if tournament has started
    const now = new Date();
    if (tournamentData.startDate.toDate() > now) {
      throw new functions.https.HttpsError(
          "failed-precondition",
          "Tournament has not started yet",
      );
    }

    // Check if tournament has ended
    if (tournamentData.endDate.toDate() < now) {
      throw new functions.https.HttpsError(
          "failed-precondition",
          "Tournament has already ended",
      );
    }

    // Check if tournament is premium-only
    if (tournamentData.isPremiumOnly) {
      // Get user data to check premium status
      const userDoc = await db.collection("users").doc(userId).get();

      if (!userDoc.exists) {
        throw new functions.https.HttpsError(
            "not-found",
            "User not found",
        );
      }

      const userData = userDoc.data();

      if (!userData.isPremium) {
        throw new functions.https.HttpsError(
            "permission-denied",
            "This tournament is for premium users only",
        );
      }
    }

    // Check if user is already in the tournament
    const participantQuery = await db.collection("tournament_participants")
        .where("tournamentId", "==", data.tournamentId)
        .where("userId", "==", userId)
        .limit(1)
        .get();

    if (!participantQuery.empty) {
      // User is already in the tournament
      return {success: true, message: "Already joined this tournament"};
    }

    // Get user data for display name
    const userDoc = await db.collection("users").doc(userId).get();

    if (!userDoc.exists) {
      throw new functions.https.HttpsError(
          "not-found",
          "User not found",
      );
    }

    const userData = userDoc.data();

    // Get today's step count
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const stepsQuery = await db.collection("steps")
        .where("userId", "==", userId)
        .where("date", "==", admin.firestore.Timestamp.fromDate(today))
        .limit(1)
        .get();

    let stepCount = 0;

    if (!stepsQuery.empty) {
      const stepsData = stepsQuery.docs[0].data();
      stepCount = stepsData.stepCount;
    }

    // Add user to tournament participants
    await db.collection("tournament_participants").add({
      tournamentId: data.tournamentId,
      userId: userId,
      displayName: userData.displayName || "",
      photoUrl: userData.photoUrl || "",
      stepCount: stepCount,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Update tournament participant count
    await tournamentDoc.ref.update({
      participantsCount: admin.firestore.FieldValue.increment(1),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {success: true, message: "Successfully joined tournament"};
  } catch (error) {
    console.error("Error joining tournament:", error);
    throw new functions.https.HttpsError("internal", "Error joining tournament");
  }
});
