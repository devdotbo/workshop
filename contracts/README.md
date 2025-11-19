# Proof of Human - Hyperlane Cross-Chain Bridge

Privacy-preserving identity verification with cross-chain bridging via Hyperlane. Verify on Celo, use on Base.

## 🎯 What This Does

**Verify once on Celo, use everywhere.** Users complete identity verification on Celo Sepolia/Mainnet, and their verification status is automatically bridged to Base Sepolia/Mainnet via Hyperlane.

## 📦 Contracts

### ProofOfHuman (Original)
Base contract for Self Protocol identity verification on Celo.

### ProofOfHumanSender (Celo)
Extends ProofOfHuman to send verification data cross-chain via Hyperlane.

### ProofOfHumanReceiver (Base)
Receives and stores verification data on Base. Query `isVerified(address)` to check status.

## 🚀 Quick Start

### 1. Install
```bash
npm install
forge install
```

### 2. Setup Environment
```bash
cp .env.example .env
```

Edit `.env`:
```bash
PRIVATE_KEY=your_key_here
CELO_SEPOLIA_RPC_URL=https://forno.celo-sepolia.celo-testnet.org
BASE_SEPOLIA_RPC_URL=https://base-sepolia.g.alchemy.com/v2/YOUR_KEY
ETHERSCAN_API_KEY=your_api_key
```

### 3. Deploy (Testnet)

**Step 1: Deploy Receiver on Base Sepolia**
```bash
forge script script/DeployProofOfHumanReceiver.s.sol:DeployProofOfHumanReceiver \
  --rpc-url base-sepolia \
  --broadcast \
  --verify
```

Add the receiver address to `.env` as `RECEIVER_ADDRESS`.

**Step 2: Deploy Sender on Celo Sepolia**
```bash
forge script script/DeployProofOfHumanSender.s.sol:DeployProofOfHumanSender \
  --rpc-url celo-sepolia \
  --broadcast \
  --verify
```

Add the sender address to `.env` as `SENDER_ADDRESS`.

### 4. Test End-to-End

**Complete verification** at http://localhost:3000 (after starting frontend), then:

```bash
./test-bridge.sh
```

This will:
- ✅ Check verification exists on Celo
- ✅ Send message via Hyperlane
- ✅ Track delivery (2-5 minutes)
- ✅ Confirm receipt on Base

## 🌐 Deployed Contracts (Testnet)

### Celo Sepolia → Base Sepolia

**Sender (Celo Sepolia)**
- Address: `0xC950D92A24005D0D9F3CD8f924263B62172C20CB`
- [View on Explorer](https://sepolia.celoscan.io/address/0xC950D92A24005D0D9F3CD8f924263B62172C20CB)

**Receiver (Base Sepolia)**
- Address: `0xf9F885F857709a47ca2d0dBe92fd0eA75746d10e`
- [View on Explorer](https://sepolia.basescan.org/address/0xf9F885F857709a47ca2d0dBe92fd0eA75746d10e)

## 📖 Usage

### Complete Verification
1. Update frontend `.env` with sender contract address
2. Start frontend: `cd ../app && npm run dev`
3. Open http://localhost:3000
4. Scan QR code with Self app
5. Complete verification

### Bridge to Base
```bash
forge script script/SendVerificationCrossChain.s.sol:SendVerificationCrossChain \
  --rpc-url celo-sepolia \
  --broadcast
```

### Check Verification on Base
```bash
source .env
cast call $RECEIVER_ADDRESS \
  "isVerified(address)(bool)" \
  <USER_ADDRESS> \
  --rpc-url base-sepolia
```

### Query Verification Data
```bash
cast call $RECEIVER_ADDRESS \
  "getVerification(address)" \
  <USER_ADDRESS> \
  --rpc-url base-sepolia
```

### Get Verification Count
```bash
cast call $RECEIVER_ADDRESS \
  "verificationCount()(uint256)" \
  --rpc-url base-sepolia
```

## 🔧 Development

### Build
```bash
forge build
```

### Test
```bash
forge test -vv
```

**Test Results:** 12/12 core tests passing ✅

### Format
```bash
forge fmt
```

## 🌍 Network Configuration

### Celo Sepolia (Testnet)
- Chain ID: `11142220`
- Identity Hub V2: `0x16ECBA51e18a4a7e61fdC417f0d47AFEeDfbed74`
- Hyperlane Mailbox: `0xD0680F80F4f947968206806C2598Cbc5b6FE5b03`
- RPC: `https://forno.celo-sepolia.celo-testnet.org`
- Faucet: https://faucet.celo.org/alfajores

### Base Sepolia (Testnet)
- Chain ID: `84532`
- Hyperlane Mailbox: `0x6966b0E55883d49BFB24539356a2f8A673E02039`
- RPC: Get from Alchemy/Infura
- Faucet: https://www.alchemy.com/faucets/base-sepolia

### Celo Mainnet
- Chain ID: `42220`
- RPC: `https://forno.celo.org`
- Hyperlane Mailbox: Check [Hyperlane Docs](https://docs.hyperlane.xyz/docs/reference/domains)

### Base Mainnet
- Chain ID: `8453`
- RPC: Use Alchemy/Infura
- Hyperlane Mailbox: Check [Hyperlane Docs](https://docs.hyperlane.xyz/docs/reference/domains)

## 💰 Gas Costs (Testnet)

| Operation | Chain | Cost |
|-----------|-------|------|
| Deploy Receiver | Base Sepolia | ~$0.00 |
| Deploy Sender | Celo Sepolia | ~$0.15 |
| Send Message | Celo Sepolia | ~$0.01 |
| Receive | Base Sepolia | Free (relayer pays) |

**Total per verification: ~$0.01**

## 🔒 Security Features

### Trusted Sender Enforcement
For production, enable trusted sender verification:

```bash
# Enable enforcement
cast send $RECEIVER_ADDRESS \
  "setTrustedSenderEnforcement(bool)" \
  true \
  --rpc-url base-sepolia \
  --private-key $PRIVATE_KEY

# Add trusted sender
cast send $RECEIVER_ADDRESS \
  "addTrustedSender(address)" \
  $SENDER_ADDRESS \
  --rpc-url base-sepolia \
  --private-key $PRIVATE_KEY
```

### Origin Validation
- Receiver automatically validates message origin
- Only accepts messages from configured source chain
- Enforced at Hyperlane protocol level

## 📚 Architecture

```
┌─────────────────────┐         Hyperlane          ┌──────────────────────┐
│   Celo Sepolia      │    ──────────────────▶     │    Base Sepolia      │
│                     │      2-5 minutes            │                      │
│  ProofOfHumanSender │                             │ ProofOfHumanReceiver │
│  - Verify identity  │                             │  - Store verification│
│  - Send via Mailbox │                             │  - Query: isVerified │
└─────────────────────┘                             └──────────────────────┘
```

## 🧪 Testing

### Receiver Tests (12/12 passing)
- ✅ Message handling
- ✅ Origin validation
- ✅ Trusted sender enforcement
- ✅ Access control
- ✅ Multiple verifications

### Integration Test
```bash
./test-bridge.sh
```

Expected output:
```
✅ Verification found on sender
✅ Message sent via Hyperlane
✅ Message delivered
✅ Verification received on Base
Total verifications: X
```

## 🔗 Integration Example

Use verification in your Base contracts:

```solidity
import {ProofOfHumanReceiver} from "./ProofOfHumanReceiver.sol";

contract YourContract {
    ProofOfHumanReceiver public verifier;
    
    constructor(address _verifier) {
        verifier = ProofOfHumanReceiver(_verifier);
    }
    
    modifier onlyVerifiedHuman() {
        require(verifier.isVerified(msg.sender), "Not verified");
        _;
    }
    
    function humanOnlyFunction() external onlyVerifiedHuman {
        // Your logic
    }
}
```

## 📝 Verification Config

Current configuration:
- Minimum age: 18 years
- Forbidden countries: None (permissionless)
- OFAC screening: Disabled

## 🔗 Resources

- [Self Protocol Docs](https://docs.self.id)
- [Hyperlane Docs](https://docs.hyperlane.xyz)
- [Hyperlane Explorer](https://explorer.hyperlane.xyz)
- [Foundry Book](https://book.getfoundry.sh)

## 🚨 Troubleshooting

### Message not delivered?
- Check [Hyperlane Explorer](https://explorer.hyperlane.xyz) with message ID
- Verify sufficient gas was paid (0.001 CELO minimum)
- Wait up to 5 minutes for relayer delivery

### Verification failed?
- Ensure verification completed on sender contract
- Check `verificationSuccessful()` returns `true`
- Verify user address matches

### RPC issues?
- Base: Use paid RPC (Alchemy recommended)
- Celo: Public RPC works but may be rate-limited

## 📄 License

MIT
