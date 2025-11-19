#!/bin/bash
set -e

source .env

echo "═══════════════════════════════════════════════════════════════"
echo "🧪 Hyperlane Bridge End-to-End Test"
echo "═══════════════════════════════════════════════════════════════"
echo ""

echo "📍 Deployed Contracts:"
echo "   Sender (Celo Sepolia): $SENDER_ADDRESS"
echo "   Receiver (Base Sepolia): $RECEIVER_ADDRESS"
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "STEP 1: Check Verification on Celo Sepolia"
echo "═══════════════════════════════════════════════════════════════"

VERIFIED=$(cast call $SENDER_ADDRESS "verificationSuccessful()(bool)" --rpc-url $CELO_SEPOLIA_RPC_URL)
if [ "$VERIFIED" = "true" ]; then
    echo "✅ Verification found on sender contract!"
    USER_ADDRESS=$(cast call $SENDER_ADDRESS "lastUserAddress()(address)" --rpc-url $CELO_SEPOLIA_RPC_URL)
    echo "   User Address: $USER_ADDRESS"
else
    echo "❌ No verification found. Complete verification first at http://localhost:3000"
    exit 1
fi
echo ""

# Check current state on Base BEFORE sending
INITIAL_COUNT=$(cast call $RECEIVER_ADDRESS "verificationCount()(uint256)" --rpc-url $BASE_SEPOLIA_RPC_URL)
echo "📊 Current state on Base Sepolia:"
echo "   Verification count: $INITIAL_COUNT"
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "STEP 2: Send Verification Cross-Chain"
echo "═══════════════════════════════════════════════════════════════"
echo "Sending verification from Celo to Base via Hyperlane..."
echo ""

# Capture full output and extract message ID
SCRIPT_OUTPUT=$(forge script script/SendVerificationCrossChain.s.sol:SendVerificationCrossChain \
  --rpc-url celo-sepolia \
  --broadcast 2>&1)

# Check if script succeeded
if echo "$SCRIPT_OUTPUT" | grep -q "ONCHAIN EXECUTION COMPLETE & SUCCESSFUL"; then
    echo "✅ Transaction broadcast successful!"
    
    # Extract message ID from the decimal output
    MESSAGE_ID_DEC=$(echo "$SCRIPT_OUTPUT" | grep "Message ID:" | awk '{print $NF}')
    
    if [ -n "$MESSAGE_ID_DEC" ]; then
        # Convert decimal to hex
        MESSAGE_ID=$(cast --to-base $MESSAGE_ID_DEC 16)
        echo "   Message ID: $MESSAGE_ID"
        echo ""
        
        echo "═══════════════════════════════════════════════════════════════"
        echo "STEP 3: Track Message on Hyperlane"
        echo "═══════════════════════════════════════════════════════════════"
        echo "🔗 Track at: https://explorer.hyperlane.xyz/message/$MESSAGE_ID"
        echo ""
        echo "Waiting for message delivery (typically 2-5 minutes)..."
        echo ""
        
        # Check for delivery (try for up to 6 minutes)
        DELIVERED="false"
        for i in {1..36}; do
            sleep 10
            DELIVERED=$(cast call $SENDER_ADDRESS "isDelivered(bytes32)(bool)" $MESSAGE_ID --rpc-url $CELO_SEPOLIA_RPC_URL 2>/dev/null || echo "false")
            if [ "$DELIVERED" = "true" ]; then
                echo "✅ Message delivery confirmed!"
                break
            fi
            echo "⏳ Checking... ($((i*10))s elapsed)"
        done
    else
        echo "⚠️  Could not extract message ID from output"
        DELIVERED="unknown"
    fi
else
    echo "❌ Transaction failed. Check the output above for errors."
    echo "$SCRIPT_OUTPUT"
    exit 1
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "STEP 4: Verify Receipt on Base Sepolia"
echo "═══════════════════════════════════════════════════════════════"

# Give it a moment
sleep 5

NEW_COUNT=$(cast call $RECEIVER_ADDRESS "verificationCount()(uint256)" --rpc-url $BASE_SEPOLIA_RPC_URL)
echo "📊 Verification count on Base: $NEW_COUNT (was $INITIAL_COUNT)"

if [ "$NEW_COUNT" -gt "$INITIAL_COUNT" ]; then
    echo "✅ New verification received on Base Sepolia!"
    echo ""
    
    # Check if the user is verified
    IS_VERIFIED=$(cast call $RECEIVER_ADDRESS "isVerified(address)(bool)" $USER_ADDRESS --rpc-url $BASE_SEPOLIA_RPC_URL)
    echo "   User $USER_ADDRESS verified: $IS_VERIFIED"
    
    if [ "$IS_VERIFIED" = "true" ]; then
        echo ""
        echo "📋 Verification Data:"
        cast call $RECEIVER_ADDRESS "getVerification(address)" $USER_ADDRESS --rpc-url $BASE_SEPOLIA_RPC_URL
    fi
else
    echo "⏳ Verification count unchanged. Message may still be in transit."
    echo "   Check Hyperlane Explorer or wait a bit longer and run:"
    echo "   cast call $RECEIVER_ADDRESS 'verificationCount()(uint256)' --rpc-url base-sepolia"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "🎉 Test Complete!"
echo "═══════════════════════════════════════════════════════════════"
echo ""

if [ "$NEW_COUNT" -gt "$INITIAL_COUNT" ]; then
    echo "✅ SUCCESS: Cross-chain verification bridge is working!"
    echo ""
    echo "Summary:"
    echo "  • Verification completed on Celo Sepolia"
    echo "  • Message sent via Hyperlane"
    echo "  • Verification received on Base Sepolia"
    echo "  • Total verifications on Base: $NEW_COUNT"
else
    echo "⏳ PENDING: Message sent but not yet confirmed on Base"
    echo ""
    echo "This is normal - Hyperlane delivery can take a few minutes."
    echo "Check the Hyperlane Explorer link above for status."
fi

echo ""
echo "🔗 View on Explorers:"
echo "   Sender: https://sepolia.celoscan.io/address/$SENDER_ADDRESS"
echo "   Receiver: https://sepolia.basescan.org/address/$RECEIVER_ADDRESS"
