// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {ProofOfHumanSender} from "../src/ProofOfHumanSender.sol";
import {SelfUtils} from "@selfxyz/contracts/contracts/libraries/SelfUtils.sol";

/**
 * @title DeployProofOfHumanSender
 * @notice Deployment script for ProofOfHumanSender contract on source chain
 * @dev Example deployment to Celo Sepolia targeting Base Sepolia
 * 
 * Run with:
 * forge script script/DeployProofOfHumanSender.s.sol:DeployProofOfHumanSender \
 *   --rpc-url celo-sepolia \
 *   --broadcast \
 *   --verify
 */
contract DeployProofOfHumanSender is Script {
    // ============ Celo Sepolia Configuration ============
    
    /// @notice Identity Verification Hub V2 on Celo Sepolia
    address constant IDENTITY_HUB_V2_SEPOLIA = 0x16ECBA51e18a4a7e61fdC417f0d47AFEeDfbed74;
    
    /// @notice Hyperlane Mailbox on Celo Sepolia
    address constant MAILBOX_CELO_SEPOLIA = 0xD0680F80F4f947968206806C2598Cbc5b6FE5b03;
    
    /// @notice Base Sepolia domain ID
    uint32 constant BASE_SEPOLIA_DOMAIN = 84532;
    
    // ============ Configuration ============
    
    /// @notice Scope seed for the contract
    string constant SCOPE_SEED = "proof-of-human-hyperlane";
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Read the receiver address from environment (must be deployed first)
        address receiverAddress = vm.envAddress("RECEIVER_ADDRESS");

        console2.log("=== Deploying ProofOfHumanSender on Celo Sepolia ===");
        console2.log("Deployer:", deployer);
        console2.log("Identity Hub V2:", IDENTITY_HUB_V2_SEPOLIA);
        console2.log("Mailbox:", MAILBOX_CELO_SEPOLIA);
        console2.log("Destination Domain (Base Sepolia):", BASE_SEPOLIA_DOMAIN);
        console2.log("Default Receiver:", receiverAddress);

        // Create verification config (matching the frontend)
        string[] memory forbiddenCountries = new string[](0); // Empty for permissionless
        
        SelfUtils.UnformattedVerificationConfigV2 memory verificationConfig = 
            SelfUtils.UnformattedVerificationConfigV2({
                olderThan: 18,
                forbiddenCountries: forbiddenCountries,
                ofacEnabled: false
            });

        vm.startBroadcast(deployerPrivateKey);

        ProofOfHumanSender sender = new ProofOfHumanSender(
            IDENTITY_HUB_V2_SEPOLIA,
            SCOPE_SEED,
            verificationConfig,
            MAILBOX_CELO_SEPOLIA,
            BASE_SEPOLIA_DOMAIN,
            receiverAddress
        );

        vm.stopBroadcast();

        console2.log("\n=== Deployment Complete ===");
        console2.log("ProofOfHumanSender deployed at:", address(sender));
        console2.log("Local domain:", sender.localDomain());
        console2.log("Destination domain:", sender.DESTINATION_DOMAIN());
        console2.log("Default recipient:", sender.defaultRecipient());

        console2.log("\n=== Next Steps ===");
        console2.log("1. Add this to .env:");
        console2.log("   SENDER_ADDRESS=%s", address(sender));
        console2.log("2. Complete verification through the frontend");
        console2.log("3. Send verification cross-chain using:");
        console2.log("   forge script script/SendVerificationCrossChain.s.sol --broadcast");
    }
}

