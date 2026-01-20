// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Ankh} from "../src/Ankh.sol";
import {Chest} from "../src/Chest.sol";
import {Prizes} from "../src/Prizes.sol";
import {MythicChest} from "../src/MythicChest.sol";

contract DeployAll is Script {
    function run() external returns (Ankh, Chest, Prizes, MythicChest) {
        // ================================================================
        // 1. LOAD CONFIGURATION
        // ================================================================

        address deployer = vm.envAddress("DEPLOYER_ADDRESS");

        string memory chestUri = vm.envString("CHEST_BASE_URI");
        string memory prizesUri = vm.envString("PRIZES_BASE_URI");

        address vrfCoordinator = vm.envAddress("VRF_COORDINATOR");
        bytes32 keyHash = vm.envBytes32("KEY_HASH");
        uint256 subId = vm.envUint("SUBSCRIPTION_ID");
        uint32 gasLimit = uint32(vm.envUint("CALLBACK_GAS_LIMIT"));
        uint256 price = vm.envUint("CHEST_PRICE");

        // ================================================================
        // 2. START BROADCAST (Real Transactions)
        // ================================================================
        vm.startBroadcast(deployer);

        // --- Step A: Deploy Assets ---
        console.log("Deploying Ankh Token...");
        Ankh ankh = new Ankh();

        console.log("Deploying Chest Contract...");
        Chest chest = new Chest(chestUri);

        console.log("Deploying Prizes Contract...");
        Prizes prizes = new Prizes(prizesUri);

        // --- Step B: Deploy Controller ---
        console.log("Deploying MythicChest Controller...");
        MythicChest controller = new MythicChest(
            address(ankh), address(chest), address(prizes), vrfCoordinator, keyHash, true, subId, gasLimit, price
        );

        // ================================================================
        // 3. SETUP PERMISSIONS (The Magic Part)
        // ================================================================
        console.log("Setting up permissions...");

        // 1. Grant MINTER_ROLE on Chest to Controller
        bytes32 minterRole = chest.MINTER_ROLE();
        chest.grantRole(minterRole, address(controller));
        console.log(" -> Controller granted MINTER_ROLE on Chest");

        // 2. Link Controller to Prizes
        prizes.setMythicChestAddress(address(controller));
        console.log(" -> Controller linked to Prizes contract");

        vm.stopBroadcast();

        // ================================================================
        // 4. LOG FINAL ADDRESSES
        // ================================================================
        console.log("--------------------------------------------------");
        console.log("DEPLOYMENT COMPLETE");
        console.log("--------------------------------------------------");
        console.log("Ankh Token:    ", address(ankh));
        console.log("Chest NFT:     ", address(chest));
        console.log("Prizes NFT:    ", address(prizes));
        console.log("Controller:    ", address(controller));
        console.log("--------------------------------------------------");

        return (ankh, chest, prizes, controller);
    }
}
