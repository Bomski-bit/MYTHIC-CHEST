// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MythicChest} from "../../src/MythicChest.sol"; // Adjust path
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IChest, IPrizes} from "../../src/MythicChest.sol";

contract MythicChestHandler is Test {
    MythicChest public mythicChest;
    IERC20 public ankh;
    address public admin;
    address public vrfCoordinator;

    // Ghost Variables
    uint256 public ghost_expectedBalance;
    uint256 public ghost_burnedCount;
    uint256 public ghost_mintedCount;
    uint256 public ghost_pendingRequests;

    uint256[] public requestIds;

    constructor(MythicChest _mythicChest, IERC20 _ankh, address _admin, address _vrfCoordinator) {
        mythicChest = _mythicChest;
        ankh = _ankh;
        admin = _admin;
        vrfCoordinator = _vrfCoordinator;
    }

    function buyChest(uint256 amount) public {
        if (mythicChest.paused()) return;

        amount = bound(amount, 1, 25);

        uint256 price = mythicChest.chestPrice();
        uint256 totalCost = price * amount;

        deal(address(ankh), msg.sender, totalCost);

        vm.startPrank(msg.sender);
        ankh.approve(address(mythicChest), totalCost);

        uint256 balanceBefore = ankh.balanceOf(address(mythicChest));
        mythicChest.buyChest(amount);
        uint256 balanceAfter = ankh.balanceOf(address(mythicChest));
        vm.stopPrank();

        // Update Invariant Tracker
        ghost_expectedBalance += (balanceAfter - balanceBefore);
    }

    function openChest(uint256 amount) public {
        amount = bound(amount, 1, mythicChest.MAX_BATCH_SIZE());

        if (mythicChest.paused()) return;

        if (IChest(mythicChest.I_CHEST()).balanceOf(msg.sender, 0) < amount) return;

        vm.prank(msg.sender);
        uint256 requestId = mythicChest.openChest(amount);

        requestIds.push(requestId);

        // Update Invariant Trackers
        ghost_burnedCount += amount;
        ghost_pendingRequests += amount;
    }

    function fulfillRandomness(uint256 seed) public {
        // 1. If there are no requests, we can't fulfill anything!
        if (requestIds.length == 0) return;

        // 2. Use the 'seed' from the fuzzer to pick a random requestId from our list
        uint256 index = seed % requestIds.length;
        uint256 requestId = requestIds[index];

        (address opener, uint256 amount) = mythicChest.requestIdToRequest(requestId);
        if (opener == address(0)) return;

        // 3. Create mock random words (one for each chest in the batch)
        uint256[] memory randomWords = new uint256[](amount);
        for (uint256 i = 0; i < amount; i++) {
            randomWords[i] = uint256(keccak256(abi.encode(requestId, i)));
        }

        // 4. Call the contract
        vm.prank(vrfCoordinator);
        mythicChest.rawFulfillRandomWords(requestId, randomWords);

        // 5. Cleanup the array (Swap and Pop)
        requestIds[index] = requestIds[requestIds.length - 1];
        requestIds.pop();

        // 6. Update Ghost Variables
        ghost_mintedCount += amount;
        ghost_pendingRequests -= amount;
    }

    function withdrawRevenue(address to) public {
        if (to == address(0)) return;
        if (to == address(mythicChest)) return;
        if (to == address(ankh)) return;
        if (mythicChest.paused()) return;

        uint256 balanceBefore = ankh.balanceOf(address(mythicChest));
        if (balanceBefore == 0) return;
        if (!mythicChest.hasRole(mythicChest.DEFAULT_ADMIN_ROLE(), admin)) {
            return;
        }

        vm.prank(admin); // Assuming ownable or check roles
        mythicChest.withdrawRevenue(to);

        uint256 balanceAfter = ankh.balanceOf(address(mythicChest));

        ghost_expectedBalance -= (balanceBefore - balanceAfter);
    }
}
