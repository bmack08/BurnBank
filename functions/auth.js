const crypto = require("crypto");

module.exports = (admin, functions) => {
  const db = admin.firestore();

  function generateReferralCode(uid) {
    const hash = crypto.createHash("md5").update(uid).digest("hex");
    return hash.substr(0, 8).toUpperCase();
  }

  const createUserRecord = functions.auth.user().onCreate(async (user) => {
    try {
      const referralCode = generateReferralCode(user.uid);
      const customClaims = user.customClaims || {};
      const referredBy = customClaims.referredBy || null;

      const userData = {
        email: user.email || "",
        displayName: user.displayName || "",
        photoUrl: user.photoURL || "",
        isPremium: false,
        premiumExpiry: null,
        totalEarnings: 0,
        pendingCashout: 0,
        availableBalance: 0,
        currentStreak: 0,
        lifetimeSteps: 0,
        referralCode,
        referredUsers: [],
        referredBy,
        hasCompletedOnboarding: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        lastActive: admin.firestore.FieldValue.serverTimestamp(),
      };

      await db.collection("users").doc(user.uid).set(userData);

      if (referredBy) {
        await db.collection("users").doc(referredBy).update({
          referredUsers: admin.firestore.FieldValue.arrayUnion(user.uid),
        });

        await db.collection("referrals").add({
          referrerId: referredBy,
          refereeId: user.uid,
          status: "pending",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      return null;
    } catch (error) {
      console.error("Error creating user record:", error);
      return null;
    }
  });

  const checkReferralCompletion = functions.firestore
    .document("users/{userId}")
    .onUpdate(async (change, context) => {
      try {
        const userId = context.params.userId;
        const newData = change.after.data();
        const oldData = change.before.data();

        if (
          newData.referredBy &&
          newData.totalEarnings >= 5.0 &&
          oldData.totalEarnings < 5.0
        ) {
          const referralsQuery = await db
            .collection("referrals")
            .where("refereeId", "==", userId)
            .where("referrerId", "==", newData.referredBy)
            .where("status", "==", "pending")
            .limit(1)
            .get();

          if (!referralsQuery.empty) {
            const referralDoc = referralsQuery.docs[0];
            const batch = db.batch();

            batch.update(referralDoc.ref, {
              status: "completed",
              completedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            const referrerId = newData.referredBy;
            const referrerDoc = await db.collection("users").doc(referrerId).get();

            if (referrerDoc.exists) {
              batch.update(referrerDoc.ref, {
                availableBalance: admin.firestore.FieldValue.increment(1.0),
                totalEarnings: admin.firestore.FieldValue.increment(1.0),
              });

              batch.set(db.collection("transactions").doc(), {
                userId: referrerId,
                amount: 1.0,
                type: "referral_bonus",
                description: `Referral bonus for ${newData.displayName || "new user"}`,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
              });
            }

            await batch.commit();
          }
        }

        return null;
      } catch (error) {
        console.error("Error checking referral completion:", error);
        return null;
      }
    });

  return {
    createUserRecord,
    checkReferralCompletion,
  };
};
