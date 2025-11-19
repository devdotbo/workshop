// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ProofOfHuman } from "./ProofOfHuman.sol";
import { IMailboxV3 } from "./IMailboxV3.sol";
import { SelfUtils } from "@selfxyz/contracts/contracts/libraries/SelfUtils.sol";
import { TypeCasts } from "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";

/**
 * @title ProofOfHumanSender
 * @notice Extends ProofOfHuman to send verification data cross-chain via Hyperlane
 * @dev Deployed on source chain (Celo Sepolia or Celo Mainnet)
 */
contract ProofOfHumanSender is ProofOfHuman {
    using TypeCasts for address;

    // ============ Immutable Storage ============

    /// @notice Hyperlane Mailbox on source chain
    IMailboxV3 public immutable MAILBOX;

    /// @notice Destination chain domain ID (e.g., Base Sepolia = 84532)
    uint32 public immutable DESTINATION_DOMAIN;

    /// @notice Default recipient address on destination chain
    address public defaultRecipient;

    // ============ Events ============

    /**
     * @notice Emitted when verification data is sent cross-chain
     * @param messageId Hyperlane message ID
     * @param recipient Recipient address on destination chain
     * @param userAddress The verified user's address
     * @param userIdentifier The user identifier from the disclosure
     */
    event VerificationSentCrossChain(
        bytes32 indexed messageId,
        address indexed recipient,
        address indexed userAddress,
        bytes32 userIdentifier
    );

    // ============ Errors ============

    error ZeroAddressMailbox();
    error ZeroAddressRecipient();
    error InsufficientGasPayment();

    // ============ Constructor ============

    /**
     * @notice Initialize the ProofOfHumanSender contract
     * @param identityVerificationHubV2Address The address of the Identity Verification Hub V2
     * @param scopeSeed The scope seed used to create the scope of the contract
     * @param _verificationConfig The verification configuration for processing proofs
     * @param _mailbox Address of the Hyperlane Mailbox on source chain
     * @param _destinationDomain Domain ID of the destination chain
     * @param _defaultRecipient Default recipient address on destination chain
     */
    constructor(
        address identityVerificationHubV2Address,
        string memory scopeSeed,
        SelfUtils.UnformattedVerificationConfigV2 memory _verificationConfig,
        address _mailbox,
        uint32 _destinationDomain,
        address _defaultRecipient
    )
        ProofOfHuman(
            identityVerificationHubV2Address,
            scopeSeed,
            _verificationConfig
        )
    {
        if (_mailbox == address(0)) revert ZeroAddressMailbox();
        if (_defaultRecipient == address(0)) revert ZeroAddressRecipient();
        
        MAILBOX = IMailboxV3(_mailbox);
        DESTINATION_DOMAIN = _destinationDomain;
        defaultRecipient = _defaultRecipient;
    }

    /**
     * @notice Receive function to accept refunds from Hyperlane hooks
     * @dev Mailbox hooks refund excess msg.value after paying fees
     */
    receive() external payable {}

    // ============ External Functions ============

    /**
     * @notice Send verification data to destination chain via Hyperlane
     * @param recipient Address of the recipient contract on destination chain
     * @return messageId Hyperlane message identifier
     * @dev Requires payment for gas on destination chain (send ETH with transaction)
     */
    function sendVerificationCrossChain(address recipient)
        external
        payable
        returns (bytes32 messageId)
    {
        if (recipient == address(0)) revert ZeroAddressRecipient();
        if (!verificationSuccessful) revert("No verification to send");
        if (msg.value == 0) revert InsufficientGasPayment();

        // Encode the verification data
        // Note: Only sending basic verification data. Expand to include disclosure fields as needed
        bytes memory message = abi.encode(
            bytes32(lastOutput.userIdentifier),
            lastUserAddress,
            lastUserData,
            block.timestamp
        );

        // Convert recipient address to bytes32 for Hyperlane
        bytes32 recipientBytes32 = recipient.addressToBytes32();

        // Dispatch message via Hyperlane Mailbox
        messageId = MAILBOX.dispatch{value: msg.value}(
            DESTINATION_DOMAIN,
            recipientBytes32,
            message
        );

        emit VerificationSentCrossChain(
            messageId,
            recipient,
            lastUserAddress,
            bytes32(lastOutput.userIdentifier)
        );
    }

    /**
     * @notice Send verification data to default recipient on destination chain
     * @return messageId Hyperlane message identifier
     */
    function sendVerificationToDefaultRecipient()
        external
        payable
        returns (bytes32 messageId)
    {
        return this.sendVerificationCrossChain{value: msg.value}(defaultRecipient);
    }

    /**
     * @notice Update the default recipient address
     * @param newRecipient New default recipient address
     * @dev Could add access control here if needed
     */
    function updateDefaultRecipient(address newRecipient) external {
        if (newRecipient == address(0)) revert ZeroAddressRecipient();
        defaultRecipient = newRecipient;
    }

    // ============ View Functions ============

    /**
     * @notice Get the local domain (chain) ID
     * @return Local domain identifier
     */
    function localDomain() external view returns (uint32) {
        return MAILBOX.localDomain();
    }

    /**
     * @notice Check if a message has been delivered
     * @param messageId The message ID to check
     * @return True if delivered, false otherwise
     */
    function isDelivered(bytes32 messageId) external view returns (bool) {
        return MAILBOX.delivered(messageId);
    }
}

