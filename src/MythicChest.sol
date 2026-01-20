// SPDX-License-Identifier: MIT

////////////////////////////////////////////////////////////////////////////////
//                                                                            //
//    PROJECT:    Mythic Chest                                                //
//    CONTRACT:   MythicChest.sol                                             //
//    AUTHOR:     Ogolo Boma                                                  //
//    DATE:       2026                                                        //
//                                                                            //
//    DESCRIPTION:                                                            //
//    Main controller for the game loop. Handles Chest purchases,             //
//    Chainlink VRF requests, and Prize distribution.                         //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title IChest
 * @author Ogolo Boma
 * @notice  Interface for Chest asset contracts (ERC1155-based minting and burning)
 * @dev Ensure implementing contracts match these exact function signatures
 */
interface IChest is IERC1155 {
    function mint(address account, uint256 id, uint256 amount, bytes calldata data) external;
    function burn(address account, uint256 id, uint256 amount) external;
}

/**
 * @title IPrizes
 * @author Ogolo Boma
 * @notice Interface for Prizes asset contracts (ERC1155-based minting)
 * @dev Ensure implementing contracts match these exact function signatures
 */
interface IPrizes is IERC1155 {
    function mint(address to, uint256 id, uint256 amount) external;
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) external;
}

contract MythicChest is AccessControl, ReentrancyGuard, Pausable, VRFConsumerBaseV2Plus {
    using SafeERC20 for IERC20;

    //////////////////////////////////////////////////////////////////////////////////////////
    //                                 ERRORS
    //////////////////////////////////////////////////////////////////////////////////////////

    error MythicChest__RequestNotFound();
    error MythicChest__InvalidPaymentAmount();
    error MythicChest__ZeroAddress();
    error MythicChest__InvalidAmount();
    error MythicChest__BatchTooLarge();
    error MythicChest__ETHTransferFailed();

    //////////////////////////////////////////////////////////////////////////////////////////
    //                             TYPE DECLARATIONS
    //////////////////////////////////////////////////////////////////////////////////////////
    struct ChestRequest {
        address opener;
        uint256 amount;
    }

    //////////////////////////////////////////////////////////////////////////////////////////
    //                             STATE VARIABLES
    //////////////////////////////////////////////////////////////////////////////////////////

    // ========= Roles ============
    /// @notice Role identifier for admin accounts.
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // ============ External Contracts ============
    /// @notice The ANKH token contract.
    IERC20 public immutable I_ANKH;

    /// @notice The Chest (ERC1155) contract.
    IChest public immutable I_CHEST;

    /// @notice The Prizes (ERC1155) contract.
    IPrizes public immutable I_PRIZES;

    // ============ Config ============
    /// @notice The price of a single chest in ANKH.
    uint256 public chestPrice;

    /// @notice The ID of the chest token.
    uint256 public constant CHEST_ID = 0;

    /// @notice Maximum number of chests that can be opened in a single batch.
    uint32 public constant MAX_BATCH_SIZE = 25;

    // ============ Chainlink VRF ============

    /// @notice Whether VRF is paid in native gas (true) or LINK (false)
    bool private immutable USE_NATIVE_PAYMENT;

    /// @notice Key hash used for Chainlink VRF requests
    bytes32 private immutable KEY_HASH;

    /// @notice Chainlink VRF subscription ID
    uint256 private immutable SUBSCRIPTION_ID;

    /// @notice Gas limit for the VRF callback function
    /// @dev Ensure this limit is high enough for 25 mints!
    uint32 private immutable CALLBACK_GAS_LIMIT;

    /// @notice Number of confirmations to wait before fulfilling VRF requests
    uint16 private constant REQUEST_CONFIRMATIONS = 3;

    /// @notice Number of random words to request from VRF
    uint32 private constant NUM_WORDS = 1;

    /// @notice Maximum value for chance calculations
    uint256 private constant MAX_CHANCE_VALUE = 1000;

    /// @notice Maps Chainlink VRF request IDs to chest opening requests.
    mapping(uint256 => ChestRequest) public requestIdToRequest;

    //////////////////////////////////////////////////////////////////////////////////////////
    //                                 EVENTS
    //////////////////////////////////////////////////////////////////////////////////////////
    /**
     * @notice Emitted when a user buys chests.
     * @param buyer The address of the chest buyer.
     * @param amount The number of chests bought.
     * @param price The total price paid in ANKH.
     */
    event ChestBought(address indexed buyer, uint256 amount, uint256 price);

    /**
     * @notice Emitted when a user opens chests.
     * @param opener The address of the chest opener.
     * @param requestId The Chainlink VRF request ID associated with the opening.
     */
    event ChestOpened(address indexed opener, uint256 indexed requestId);

    /**
     * @notice Emitted when a prize is dropped to a user.
     * @param to The address receiving the prize.
     * @param prizeId The ID of the prize dropped.
     * @param amount The amount of the prize dropped.
     */
    event PrizeDropped(address indexed to, uint256 indexed prizeId, uint256 amount);

    /**
     * @notice Emitted when ERC20 tokens are rescued from the contract.
     * @param token The address of the rescued token.
     * @param to The address receiving the rescued tokens.
     * @param amount The amount of tokens rescued.
     */
    event FundsRescued(address indexed token, address indexed to, uint256 amount);

    /**
     * @notice Emitted when ETH is rescued from the contract.
     * @param to The address receiving the rescued ETH.
     * @param amount The amount of ETH rescued.
     */
    event EthRescued(address indexed to, uint256 amount);

    /**
     * @notice Emitted when revenue is withdrawn from the contract.
     * @param to The address receiving the withdrawn revenue.
     * @param amount The amount of revenue withdrawn.
     */
    event RevenueWithdrawn(address indexed to, uint256 amount);

    //////////////////////////////////////////////////////////////////////////////////////////
    //                                  FUNCTIONS
    //////////////////////////////////////////////////////////////////////////////////////////
    constructor(
        address _ankh,
        address _chestContract,
        address _prizesContract,
        address _vrfCoordinator,
        bytes32 _keyHash,
        bool _useNativePayment,
        uint256 _subscriptionId,
        uint32 _callbackGasLimit,
        uint256 _initialPrice
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        if (_ankh == address(0) || _chestContract == address(0) || _prizesContract == address(0)) {
            revert MythicChest__ZeroAddress();
        }

        I_ANKH = IERC20(_ankh);
        I_CHEST = IChest(_chestContract);
        I_PRIZES = IPrizes(_prizesContract);

        KEY_HASH = _keyHash;
        SUBSCRIPTION_ID = _subscriptionId;
        CALLBACK_GAS_LIMIT = _callbackGasLimit;
        USE_NATIVE_PAYMENT = _useNativePayment;

        chestPrice = _initialPrice;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice Users buy chests here. Transfers ANKH and calls mint on Chest.sol.
     * @param amount The number of chests to buy.
     */
    function buyChest(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert MythicChest__InvalidPaymentAmount();

        uint256 totalCost = chestPrice * amount;

        // 1. Transfer ANKH (using SafeERC20)
        I_ANKH.safeTransferFrom(msg.sender, address(this), totalCost);

        // 2. Mint Chest(s)
        // Controller must have MINTER_ROLE on Chest.sol
        I_CHEST.mint(msg.sender, CHEST_ID, amount, "");

        emit ChestBought(msg.sender, amount, totalCost);
    }

    /**
     * @notice Burns multiple chests and requests multiple random words.
     * @dev Only callable by the Controller (or other addresses with MINTER_ROLE).
     * @param amount The number of chests to open (max 10).
     * @return requestId The Chainlink VRF request ID for the randomness request.
     */
    function openChest(uint256 amount) external nonReentrant whenNotPaused returns (uint256 requestId) {
        if (amount == 0) revert MythicChest__InvalidAmount();
        if (amount > MAX_BATCH_SIZE) revert MythicChest__BatchTooLarge();

        // 1. Burn 'amount' Chests
        I_CHEST.burn(msg.sender, CHEST_ID, amount);

        // 2. Request Randomness
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: KEY_HASH,
            subId: SUBSCRIPTION_ID,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: CALLBACK_GAS_LIMIT,
            numWords: uint32(amount),
            extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: USE_NATIVE_PAYMENT}))
        });

        requestId = s_vrfCoordinator.requestRandomWords(request);

        // 3. Store the Request Info
        requestIdToRequest[requestId] = ChestRequest({opener: msg.sender, amount: amount});

        emit ChestOpened(msg.sender, requestId);
    }

    /**
     * @notice Callback from Chainlink VRF. Mints the weapon.
     * @dev Handles multiple prizes per request for gas efficiency.
     * @param requestId The ID of the randomness request.
     * @param randomWords The array of random words provided by Chainlink VRF.
     */
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        ChestRequest memory request = requestIdToRequest[requestId];
        if (request.opener == address(0)) revert MythicChest__RequestNotFound();

        // ==== STEP 1: Aggregate Results in Memory ====
        /// @notice Size 17 because IDs are 1-indexed (index 0 is unused)
        uint256[17] memory prizeCounts;
        uint256 uniquePrizesCount = 0;

        for (uint256 i = 0; i < request.amount; ++i) {
            uint256 prizeId = _determinePrize(randomWords[i]);

            // If this is the first time we see this prize in this batch, increment unique counter
            if (prizeCounts[prizeId] == 0) {
                ++uniquePrizesCount;
            }

            // Increment the count for this specific prize ID
            ++prizeCounts[prizeId];
        }

        // ==== STEP 2: Build Arrays for mintBatch ====
        uint256[] memory distinctIds = new uint256[](uniquePrizesCount);
        uint256[] memory distinctAmounts = new uint256[](uniquePrizesCount);

        uint256 currentIndex = 0;

        // Loop through our counting array to populate the final arrays
        for (uint256 id = 1; id < 17; ++id) {
            if (prizeCounts[id] > 0) {
                distinctIds[currentIndex] = id;
                distinctAmounts[currentIndex] = prizeCounts[id];
                ++currentIndex;
            }
        }

        delete requestIdToRequest[requestId];

        // ==== STEP 3: Single External Call to Mint Prizes ====
        I_PRIZES.mintBatch(request.opener, distinctIds, distinctAmounts, "");

        // ==== STEP 4: Emit Events ====
        /// @notice We still emit individual events for the frontend/subgraph to track easily
        for (uint256 i = 0; i < uniquePrizesCount; ++i) {
            emit PrizeDropped(request.opener, distinctIds[i], distinctAmounts[i]);
        }
    }

    function _determinePrize(uint256 randomNumber) internal pure returns (uint8) {
        uint256 moddedRng = randomNumber % MAX_CHANCE_VALUE;

        /// @notice Common (17.5% each) -> Cumulative: 175, 350, 525, 700
        if (moddedRng < 175) return 1; // Greek Common
        if (moddedRng < 350) return 2; // Roman Common
        if (moddedRng < 525) return 3; // Egyptian Common
        if (moddedRng < 700) return 4; // Norse Common

        /// @notice Uncommon (5.0% each) -> Cumulative: 750, 800, 850, 900
        if (moddedRng < 750) return 5; // Greek Uncommon
        if (moddedRng < 800) return 6; // Roman Uncommon
        if (moddedRng < 850) return 7; // Egyptian Uncommon
        if (moddedRng < 900) return 8; // Norse Uncommon

        /// @notice Rare (2.0% each) -> Cumulative: 920, 940, 960, 980
        if (moddedRng < 920) return 9; // Greek Rare
        if (moddedRng < 940) return 10; // Roman Rare
        if (moddedRng < 960) return 11; // Egyptian Rare
        if (moddedRng < 980) return 12; // Norse Rare

        /// @notice Legendary (0.5% each) -> Cumulative: 985, 990, 995, 1000
        if (moddedRng < 985) return 13; // Greek Legendary
        if (moddedRng < 990) return 14; // Roman Legendary
        if (moddedRng < 995) return 15; // Egyptian Legendary

        return 16; // Norse Legendary
    }

    //////////////////////////////
    //  Admin Functions
    /////////////////////////////
    /**
     * @notice Sets a new price for chests.
     * @param newPrice The new chest price in ANKH.
     */
    function setChestPrice(uint256 newPrice) external onlyRole(ADMIN_ROLE) {
        chestPrice = newPrice;
    }

    /**
     * @notice Pauses the contract, disabling chest purchases and openings.
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @notice Unpauses the contract, enabling chest purchases and openings.
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @notice Withdraws the accumulated game revenue (ANKH) to the admin.
     * @param to The address to receive the withdrawn revenue.
     */
    function withdrawRevenue(address to) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (to == address(0)) revert MythicChest__ZeroAddress();

        // 1. Check how much ANKH is in the contract
        uint256 balance = I_ANKH.balanceOf(address(this));
        if (balance == 0) revert MythicChest__InvalidAmount();

        // 2. Transfer to the admin
        I_ANKH.safeTransfer(to, balance);
        emit RevenueWithdrawn(to, balance);
    }

    /**
     * @notice Allows the owner to withdraw any ERC-20 token sent to this contract.
     * @dev Useful for rescuing accidentally sent tokens.
     * @param _token The contract address of the token to withdraw.
     * @param _to The address to send the tokens to.
     * @param _amount The amount to withdraw.
     */
    function rescueERC20(address _token, address _to, uint256 _amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_to == address(0)) revert MythicChest__ZeroAddress();

        // Using SafeERC20 handles non-standard tokens (like USDT) correctly
        IERC20(_token).safeTransfer(_to, _amount);
        emit FundsRescued(_token, _to, _amount);
    }

    /**
     * @notice Allows the owner to withdraw any ETH sent to this contract.
     * @dev Useful for rescuing accidentally sent ETH.
     * @param _to The address to send the ETH to.
     * @param _amount The amount of ETH to withdraw (in wei).
     */
    function rescueETH(address _to, uint256 _amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_to == address(0)) revert MythicChest__ZeroAddress();

        (bool success,) = payable(_to).call{value: _amount}("");
        if (!success) revert MythicChest__ETHTransferFailed();
        emit EthRescued(_to, _amount);
    }
}
