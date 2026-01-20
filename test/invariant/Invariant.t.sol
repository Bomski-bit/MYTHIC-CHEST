// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {MythicChestHandler} from "./Handler.sol";
import {MythicChest} from "../../src/MythicChest.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ERC1155Mock} from "../mocks/ERC1155Mock.sol";

contract MythicChestInvariants is StdInvariant, Test {
    // ============================================
    //            STATE VARIABLES
    // ============================================
    MythicChestHandler public handler;
    MythicChest public mythicChest;
    ERC20Mock public ankh;
    ERC1155Mock public chestMock;
    ERC1155Mock public prizeMock;

    // Define a specific address for the Admin
    address public constant ADMIN = address(0x1337);
    address public constant MOCK_VRF = address(0x3);

    // ============================================
    //            SETUP LOGIC
    // ============================================
    function setUp() public {
        ankh = new ERC20Mock();
        chestMock = new ERC1155Mock();
        prizeMock = new ERC1155Mock();

        // Deploy contract as the ADMIN
        vm.startPrank(ADMIN);
        mythicChest = new MythicChest(
            address(ankh),
            address(chestMock),
            address(prizeMock),
            MOCK_VRF,
            bytes32(0), // KeyHash
            true, // VRF Enabled
            0, // SubID
            500000, // Gas Limit
            10 ether // Initial Price
        );
        vm.stopPrank();

        // Initialize Handler with the ADMIN address
        handler = new MythicChestHandler(mythicChest, ankh, ADMIN, MOCK_VRF);

        // Tell Foundry's fuzzer to only call functions in the handler
        targetContract(address(handler));
    }

    // ============================================
    //            INVARIANTS
    // ============================================
    /// @custom:invariant Protocol Solvency
    function invariant_ankhBalanceMatchesExpected() public view {
        assertEq(
            ankh.balanceOf(address(mythicChest)),
            handler.ghost_expectedBalance(),
            "Solvency Error: Contract balance mismatch"
        );
    }

    /// @custom:invariant Conservation of Items
    function invariant_itemConservation() public view {
        assertEq(
            handler.ghost_burnedCount(),
            handler.ghost_mintedCount() + handler.ghost_pendingRequests(),
            "Conservation Error: Burned vs Minted mismatch"
        );
    }
}
