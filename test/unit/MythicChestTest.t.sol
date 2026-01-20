// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {MythicChest} from "../../src/MythicChest.sol";
import {Ankh} from "../../src/Ankh.sol";
import {Chest} from "../../src/Chest.sol";
import {Prizes} from "../../src/Prizes.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract MythicChestTest is Test {
    // ============================================
    //            STATE VARIABLES
    // ============================================
    MythicChest controller;
    Ankh ankh;
    Chest chest;
    Prizes prizes;
    VRFCoordinatorV2_5Mock vrfCoordinator;

    // Users
    address admin = makeAddr("admin");
    address user = makeAddr("user");

    // Config
    uint256 constant STARTING_USER_BALANCE = 1000 ether;
    uint256 constant BALANCE_TOP_UP = 5000 ether;
    uint256 constant CHEST_PRICE = 100 ether;
    bytes32 constant KEY_HASH = 0x474e34a077df58807dbe9c96d3cabb68bd679f2dd48971265246a6e509338831;
    uint256 subId;
    uint32 constant GAS_LIMIT = 500000;

    // ============================================
    //            EVENTS
    // ============================================
    event ChestBought(address indexed buyer, uint256 amount, uint256 price);
    event ChestOpened(address indexed opener, uint256 indexed requestId);
    event PrizeDropped(address indexed to, uint256 indexed prizeId, uint256 amount);
    event FundsRescued(address indexed itoken, address indexed to, uint256 amount);
    event EthRescued(address indexed to, uint256 amount);
    event RevenueWithdrawn(address indexed to, uint256 amount);

    // ============================================
    //            SETUP LOGIC
    // ============================================
    function setUp() public {
        vm.startPrank(admin);

        // 1. Deploy Mocks & Assets
        // 0.1 base fee, 1e9 gas price link (Standard Mock Config)
        vrfCoordinator = new VRFCoordinatorV2_5Mock(
            0.1 ether, // baseFee
            1e9, // gasPriceLink (still required)
            1e9 // gasPriceNative
        );
        // Capture ID
        subId = vrfCoordinator.createSubscription();

        // give the admin some native ETH to fund the subscription
        vm.deal(admin, 200 ether);

        // Fund subscription with native ETH
        vrfCoordinator.fundSubscriptionWithNative{value: 100 ether}(subId);

        // Add your consumer
        vrfCoordinator.addConsumer(subId, address(controller));

        ankh = new Ankh();
        chest = new Chest("ipfs://chest/");
        prizes = new Prizes("ipfs://prizes/");

        // 2. Deploy Controller
        controller = new MythicChest(
            address(ankh),
            address(chest),
            address(prizes),
            address(vrfCoordinator),
            KEY_HASH,
            true,
            subId,
            GAS_LIMIT,
            CHEST_PRICE
        );

        // 3. Link Permissions
        // A. Add Consumer to VRF
        vrfCoordinator.addConsumer(subId, address(controller));

        // B. Grant Controller MINTER_ROLE on Chest
        chest.grantRole(chest.MINTER_ROLE(), address(controller));

        // C. Link Prizes to Controller
        prizes.setMythicChestAddress(address(controller));

        // 4. Setup User
        // Transfer ANKH to user
        ankh.transfer(user, STARTING_USER_BALANCE);
        vm.stopPrank();

        // User approves Controller to spend ANKH
        vm.startPrank(user);
        ankh.approve(address(controller), type(uint256).max);
        vm.stopPrank();
    }

    // ============================================
    //            BUYING TESTS
    // ============================================

    function testBuyingChest() public {
        vm.prank(user);

        // Expect Event
        vm.expectEmit(true, false, false, true);
        emit ChestBought(user, 2, CHEST_PRICE * 2);

        controller.buyChest(2);

        // Check Balances
        assertEq(chest.balanceOf(user, 0), 2); // User has 2 chests
        assertEq(ankh.balanceOf(user), STARTING_USER_BALANCE - (CHEST_PRICE * 2)); // User spent ANKH
    }

    function testRevertsIfUserTriesToBuyZeroAmount() public {
        vm.prank(user);
        vm.expectRevert();
        controller.buyChest(0);
    }

    function testRevertsIfUserHasInsufficientFunds() public {
        // Create a poor user
        address poorUser = makeAddr("poor");
        vm.prank(poorUser);

        /// @notice ERC20 will revert with "insufficient allowance" or "insufficient balance"
        // Since we didn't approve, it fails at transferFrom
        vm.expectRevert();
        controller.buyChest(1);
    }

    // ============================================
    //            OPENING TESTS (VRF)
    // ============================================

    function testOpenChestWorks() public {
        // 1. Buy First
        vm.startPrank(user);
        controller.buyChest(1);

        // 2. Open
        vm.expectEmit(true, false, false, false);
        emit ChestOpened(user, 1); // Request ID will be 1 for first request

        uint256 requestId = controller.openChest(1);

        // 3. Verify Chest Burned
        assertEq(chest.balanceOf(user, 0), 0);

        // 4. Verify Request Stored
        (address opener, uint256 amount) = controller.requestIdToRequest(requestId);
        assertEq(opener, user);
        assertEq(amount, 1);
        vm.stopPrank();
    }

    /**
     * @dev This is an integration test that simulates the full flow of buying chests,
     * opening them, receiving random words from Chainlink VRF, and minting prizes.
     */
    function testFulfillRandomWordsBatchMint() public {
        uint256 openAmount = 5;

        // 1. Setup: Buy 5 chests
        vm.startPrank(user);
        controller.buyChest(openAmount);

        // 2. Open 5 chests -> Get Request ID
        uint256 requestId = controller.openChest(openAmount);
        vm.stopPrank();

        // 3. Mock Chainlink Callback
        // We act as the VRF Coordinator fulfilling the request
        // We create 5 random numbers that we know the outcome of
        uint256[] memory randomWords = new uint256[](5);
        randomWords[0] = 100; // Common (<175) -> ID 1
        randomWords[1] = 100; // Common (<175) -> ID 1
        randomWords[2] = 100; // Common (<175) -> ID 1
        randomWords[3] = 999; // Legendary (<1000) -> ID 16 (Norse)
        randomWords[4] = 930; // Rare (<940) -> ID 10

        // Foundry expects events in the order they are emitted. So we set them up accordingly:
        // 1. Expect Prize ID 1 (Common)
        vm.expectEmit(true, false, false, true);
        emit PrizeDropped(user, 1, 3);

        // 2. Expect Prize ID 10 (Rare)
        vm.expectEmit(true, false, false, true);
        emit PrizeDropped(user, 10, 1);

        // 3. Expect Prize ID 16 (Legendary)
        vm.expectEmit(true, false, false, true);
        emit PrizeDropped(user, 16, 1);

        // Perform the callback
        vm.prank(address(vrfCoordinator)); // Pretend to be Chainlink
        vrfCoordinator.fulfillRandomWordsWithOverride(requestId, address(controller), randomWords);

        // 4. Verify Prizes Minted
        // We expect: 3x ID 1, 1x ID 16, 1x ID 10
        assertEq(prizes.balanceOf(user, 1), 3, "Should have 3 Common");
        assertEq(prizes.balanceOf(user, 16), 1, "Should have 1 Legendary");
        assertEq(prizes.balanceOf(user, 10), 1, "Should have 1 Rare");

        // 5. Verify Request Deleted
        (address opener,) = controller.requestIdToRequest(requestId);
        assertEq(opener, address(0), "Request should be deleted");
    }

    function testRevertsIfUserTriesToOpenTooMany() public {
        // Top up user's ANKH balance to buy more chests
        vm.startPrank(admin);
        ankh.transfer(user, BALANCE_TOP_UP);
        vm.stopPrank();

        vm.startPrank(user);
        controller.buyChest(30);

        // Max batch size is 25
        vm.expectRevert();
        controller.openChest(26);
        vm.stopPrank();
    }

    // ============================================
    //            ADMIN TESTS
    // ============================================

    function testIfMythicChestPausesAndUnpauses() public {
        vm.prank(admin);
        controller.pause();

        vm.prank(user);
        vm.expectRevert(); // EnforcedPaused
        controller.buyChest(1);

        vm.prank(admin);
        controller.unpause();

        vm.prank(user);
        controller.buyChest(1); // Should work now
    }

    function testIfAdminCanSetPrice() public {
        vm.prank(admin);
        controller.setChestPrice(200 ether);

        assertEq(controller.chestPrice(), 200 ether);
    }

    // ============================================
    //            REVENUE WITHDRAWAL TESTS
    // ============================================

    function testWithdrawRevenueIsSuccessful() public {
        // 1. SETUP: Generate Revenue
        uint256 revenue = 500 ether; // 5 Chests

        vm.prank(user);
        controller.buyChest(5);

        // Verify contract holds the funds
        assertEq(ankh.balanceOf(address(controller)), revenue);

        // 2. SETUP: Admin snapshot
        uint256 adminStartBalance = ankh.balanceOf(admin);

        // 3. EXECUTE: Admin withdraws
        vm.startPrank(admin);

        // Expect the event
        vm.expectEmit(true, false, false, true);
        emit RevenueWithdrawn(admin, revenue);

        controller.withdrawRevenue(admin);
        vm.stopPrank();

        // 4. VERIFY: Funds moved
        assertEq(ankh.balanceOf(address(controller)), 0, "Contract should be empty");
        assertEq(ankh.balanceOf(admin), adminStartBalance + revenue, "Admin should have funds");
    }

    function testWithdrawRevenueRevertsIfBalanceIsZero() public {
        // 1. Ensure contract is empty (don't buy any chests)
        assertEq(ankh.balanceOf(address(controller)), 0);

        // 2. Expect Revert
        vm.prank(admin);
        vm.expectRevert(MythicChest.MythicChest__InvalidAmount.selector);

        controller.withdrawRevenue(admin);
    }

    function testWithdrawRevenueRevertsIfAddressIsZero() public {
        // 1. Generate some revenue so we don't hit the "InvalidAmount" error first
        vm.prank(user);
        controller.buyChest(1);

        // 2. Expect Revert
        vm.prank(admin);
        vm.expectRevert(MythicChest.MythicChest__ZeroAddress.selector);

        controller.withdrawRevenue(address(0));
    }

    function testWithdrawRevenueRevertsIfNotAdmin() public {
        address randomHacker = makeAddr("hacker");

        vm.prank(randomHacker);
        vm.expectRevert();

        controller.withdrawRevenue(randomHacker);
    }

    // ============================================
    //            RESCUE FUNDS TESTS
    // ============================================

    function testAdminCanRescueETH() public {
        // 1. Simulate someone accidentally sending ETH to the contract
        // vm.deal to force 1 ETH into the contract wallet
        uint256 amount = 1 ether;
        vm.deal(address(controller), amount);

        // Verify contract has the ETH
        assertEq(address(controller).balance, amount);

        // 2. Admin rescues it
        uint256 startBalance = admin.balance;

        vm.prank(admin);
        vm.expectEmit(false, false, false, true); // (check data only)
        emit EthRescued(admin, amount);

        controller.rescueETH(admin, amount);

        // 3. Verify Admin got the money
        assertEq(admin.balance, startBalance + amount);
        assertEq(address(controller).balance, 0);
    }

    function testAdminCanRescueERC20() public {
        // 1. Simulate someone accidentally sending ANKH to the contract
        uint256 amount = 50 ether;

        vm.prank(user);
        ankh.transfer(address(controller), amount);

        // Verify contract has the tokens
        assertEq(ankh.balanceOf(address(controller)), amount);

        // 2. Admin rescues it
        vm.prank(admin);
        vm.expectEmit(true, true, false, true);
        emit FundsRescued(address(ankh), admin, amount);

        controller.rescueERC20(address(ankh), admin, amount);

        // 3. Verify Admin received funds
        assertEq(ankh.balanceOf(admin), 1_000_000 ether - STARTING_USER_BALANCE + amount);
        assertEq(ankh.balanceOf(address(controller)), 0);
    }

    function testRevertsIfUserTriesToRescue() public {
        // Ensure a random user cannot steal funds
        vm.deal(address(controller), 1 ether);

        vm.prank(user);
        vm.expectRevert();
        controller.rescueETH(user, 1 ether);
    }
}
